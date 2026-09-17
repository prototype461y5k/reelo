//
//  VimeoAPIClient.swift
//  Reelo
//
//  All Vimeo review-folder API interactions:
//  1) Bootstrap JWT from the review page
//  2) Paginated video list
//  3) Per-video download link resolution
//  4) File download
//

import Foundation

final class VimeoAPIClient {

    // MARK: - Errors

    enum APIError: Error, LocalizedError {
        case invalidURL
        case badLinkFormat
        case pageNotReachable(status: Int)
        case bootstrapMissing
        case jwtMissing
        case notAuthorized(status: Int)          // 401 / 403
        case notFound                            // 404
        case rateLimited(retryAfter: TimeInterval?)
        case serverError(status: Int)
        case invalidJSON(detail: String)
        case noVersionFound
        case noDownloadMatch
        case downloadFailed(status: Int)
        case diskWriteFailed(String)
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Geçersiz bağlantı."
            case .badLinkFormat:
                return "Bağlantı biçimi tanınmadı. Doğru biçim: vimeo.com/reviews/{review}/users/{user}/folders/{folder}"
            case .pageNotReachable(let s):
                return "Review sayfasına ulaşılamadı (HTTP \(s)). İnternet bağlantını ve linki kontrol et."
            case .bootstrapMissing:
                return "Sayfa yapısı tanınamadı. Vimeo sayfa düzenini değiştirmiş olabilir."
            case .jwtMissing:
                return "Oturum anahtarı (JWT) alınamadı. Link herkese açık bir review linki mi?"
            case .notAuthorized(let s):
                return "Yetki reddedildi (HTTP \(s)). Bu review linki herkese açık ve parolasız olmalı."
            case .notFound:
                return "Klasör veya review bulunamadı (HTTP 404). Link süresi dolmuş ya da silinmiş olabilir."
            case .rateLimited(let ra):
                if let ra { return "Vimeo hız sınırı: \(Int(ra)) sn bekleniyor…" }
                return "Vimeo hız sınırına takıldı, bekleniyor…"
            case .serverError(let s):
                return "Vimeo sunucu hatası (HTTP \(s)). Biraz sonra tekrar dene."
            case .invalidJSON(let d):
                return "Yanıt çözümlenemedi. (\(d))"
            case .noVersionFound:
                return "Video sürümü bulunamadı."
            case .noDownloadMatch:
                return "Bu video için indirme bağlantısı bulunamadı (indirme kapalı olabilir)."
            case .downloadFailed(let s):
                return "İndirme başarısız (HTTP \(s))."
            case .diskWriteFailed(let m):
                return "Dosya diske yazılamadı: \(m)"
            case .network(let e):
                return "Ağ hatası: \(e.localizedDescription)"
            }
        }

        /// Short machine-style code shown next to messages, e.g. "REELO-401".
        var code: String {
            switch self {
            case .invalidURL: return "REELO-URL"
            case .badLinkFormat: return "REELO-FORMAT"
            case .pageNotReachable(let s): return "REELO-PAGE-\(s)"
            case .bootstrapMissing: return "REELO-BOOTSTRAP"
            case .jwtMissing: return "REELO-JWT"
            case .notAuthorized(let s): return "REELO-AUTH-\(s)"
            case .notFound: return "REELO-404"
            case .rateLimited: return "REELO-429"
            case .serverError(let s): return "REELO-SRV-\(s)"
            case .invalidJSON: return "REELO-JSON"
            case .noVersionFound: return "REELO-NOVER"
            case .noDownloadMatch: return "REELO-NODL"
            case .downloadFailed(let s): return "REELO-DL-\(s)"
            case .diskWriteFailed: return "REELO-DISK"
            case .network: return "REELO-NET"
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    private let maxRetries = 5
    private let baseBackoff: TimeInterval = 1.0
    private var cachedJWT: String?
    private var jwtExpiry: Date?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 3600
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Step 1: Bootstrap JWT

    func fetchBootstrapJWT(from reviewURL: URL) async throws -> String {
        let html = try await fetchHTML(from: reviewURL)
        guard let jsonStr = extractBootstrapJSON(from: html) else { throw APIError.bootstrapMissing }
        guard let data = jsonStr.data(using: .utf8),
              let bootstrap = try? JSONDecoder().decode(BootstrapResponse.self, from: data),
              let jwt = bootstrap.jwt, !jwt.isEmpty else {
            throw APIError.jwtMissing
        }
        cachedJWT = jwt
        jwtExpiry = decodeJWTExpiry(from: jwt)
        return jwt
    }

    func ensureJWT(from reviewURL: URL) async throws -> String {
        if let jwt = cachedJWT, let expiry = jwtExpiry, expiry > Date().addingTimeInterval(120) {
            return jwt
        }
        return try await fetchBootstrapJWT(from: reviewURL)
    }

    // MARK: - Step 2: Video list

    func fetchAllVideos(userID: String, folderID: String, reviewID: String, baseURL: URL) async throws -> [VideoItem] {
        var all: [VideoItem] = []
        var page = 1
        var totalPages = 1
        let perPage = 25
        var lastPageCount = 0

        repeat {
            let jwt = try await ensureJWT(from: baseURL)
            let (entries, total) = try await fetchVideoPage(userID: userID, folderID: folderID, reviewID: reviewID, page: page, perPage: perPage, jwt: jwt)
            lastPageCount = entries.count
            if page == 1 { totalPages = max(1, (total + perPage - 1) / perPage) }

            for e in entries {
                let videoID = VideoItem.extractVideoID(from: e.uri) ?? e.uri
                let versionID = e.currentVersionURI.flatMap { VideoItem.extractVersionID(from: $0) }
                all.append(VideoItem(
                    id: e.uri.split(separator: "/").last.map(String.init) ?? UUID().uuidString,
                    name: e.name, link: e.link, duration: e.duration,
                    versionID: versionID, videoID: videoID, thumbnailURL: e.thumbnailURL
                ))
            }
            page += 1
            if lastPageCount < perPage { break }
        } while page <= totalPages

        return all
    }

    private func fetchVideoPage(userID: String, folderID: String, reviewID: String, page: Int, perPage: Int, jwt: String) async throws -> ([VimeoVideoEntry], Int) {
        var components = URLComponents(string: "https://api.vimeo.com/users/\(userID)/projects/\(folderID)/items")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "review_id", value: reviewID),
            URLQueryItem(name: "fields", value: "video.uri,video.name,video.link,video.duration,video.pictures.sizes,video.metadata.connections.versions.current_uri")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("jwt \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.vimeo.*+json;version=3.4.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await performWithRetry { try await self.session.data(for: request) }
        let http = response as? HTTPURLResponse
        try Self.throwForStatus(http, data: data)

        do {
            let list = try JSONDecoder().decode(VimeoVideoListResponse.self, from: data)
            return (list.data, list.total)
        } catch {
            throw APIError.invalidJSON(detail: "liste: \(error.localizedDescription)")
        }
    }

    // MARK: - Step 3: Download links

    func fetchDownloadURL(video: VideoItem, reviewID: String, jwt: String, preferredQuality: String) async throws -> (url: URL, size: Int64, rendition: String) {
        let finalVersionID: String
        if let vid = video.versionID, !vid.isEmpty {
            finalVersionID = vid
        } else {
            finalVersionID = try await fetchVersionIDFromVideoDetail(videoID: video.videoID, jwt: jwt)
        }

        var components = URLComponents(string: "https://api.vimeo.com/videos/\(video.videoID)/versions/\(finalVersionID)/downloads")!
        components.queryItems = [URLQueryItem(name: "review_id", value: reviewID)]
        var request = URLRequest(url: components.url!)
        request.setValue("jwt \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.vimeo.*+json;version=3.4.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await performWithRetry { try await self.session.data(for: request) }
        try Self.throwForStatus(response as? HTTPURLResponse, data: data)

        let downloads: [DownloadInfo]
        do {
            downloads = try JSONDecoder().decode(DownloadsResponse.self, from: data).download
        } catch {
            throw APIError.invalidJSON(detail: "indirme: \(error.localizedDescription)")
        }
        guard !downloads.isEmpty else { throw APIError.noDownloadMatch }

        let best = selectBestDownload(from: downloads, preferred: preferredQuality)
        guard let url = URL(string: best.link) else { throw APIError.noDownloadMatch }
        return (url, Int64(best.size ?? 0), best.publicName ?? best.rendition ?? best.quality ?? "video")
    }

    private func fetchVersionIDFromVideoDetail(videoID: String, jwt: String) async throws -> String {
        var components = URLComponents(string: "https://api.vimeo.com/videos/\(videoID)")!
        components.queryItems = [URLQueryItem(name: "fields", value: "metadata.connections.versions.current_uri")]
        var request = URLRequest(url: components.url!)
        request.setValue("jwt \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.vimeo.*+json;version=3.4.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Self.throwForStatus(response as? HTTPURLResponse, data: data)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let metadata = json["metadata"] as? [String: Any],
           let connections = metadata["connections"] as? [String: Any],
           let versions = connections["versions"] as? [String: Any],
           let currentURI = versions["current_uri"] as? String {
            return VideoItem.extractVersionID(from: currentURI) ?? ""
        }
        throw APIError.noVersionFound
    }

    private func selectBestDownload(from downloads: [DownloadInfo], preferred: String) -> DownloadInfo {
        if preferred == "best" {
            return downloads.max { ($0.width ?? 0) < ($1.width ?? 0) } ?? downloads[0]
        }
        let targetWidth: Int
        switch preferred {
        case "1080p": targetWidth = 1920
        case "720p": targetWidth = 1280
        case "480p": targetWidth = 854
        case "360p": targetWidth = 640
        default: targetWidth = 1920
        }
        let sorted = downloads.sorted { ($0.width ?? 0) > ($1.width ?? 0) }
        if let best = sorted.first(where: { ($0.width ?? 0) <= targetWidth }) { return best }
        return sorted.last ?? downloads[0]
    }

    // MARK: - Step 4: File download (with progress)

    func downloadFile(from url: URL, to destination: URL, expectedSize: Int64, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        let delegate = DownloadProgressDelegate(progress: progressHandler)
        let dlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { dlSession.finishTasksAndInvalidate() }

        let stableTemp: URL = try await withCheckedThrowingContinuation { cont in
            delegate.completion = cont
            var request = URLRequest(url: url)
            request.timeoutInterval = 3600
            let task = dlSession.downloadTask(with: request)
            task.resume()
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.moveItem(at: stableTemp, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: stableTemp)
            throw APIError.diskWriteFailed(error.localizedDescription)
        }
        progressHandler(1.0)
        return destination
    }

    // MARK: - Helpers

    private static func throwForStatus(_ http: HTTPURLResponse?, data: Data) throws {
        guard let http else { throw APIError.invalidURL }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw APIError.notAuthorized(status: http.statusCode)
        case 404: throw APIError.notFound
        case 429:
            let ra = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
            throw APIError.rateLimited(retryAfter: ra)
        case 500...599: throw APIError.serverError(status: http.statusCode)
        default: throw APIError.serverError(status: http.statusCode)
        }
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.pageNotReachable(status: 0) }
        guard http.statusCode == 200 else { throw APIError.pageNotReachable(status: http.statusCode) }
        guard let html = String(data: data, encoding: .utf8) else { throw APIError.bootstrapMissing }
        return html
    }

    private func extractBootstrapJSON(from html: String) -> String? {
        guard let startRange = html.range(of: #"id="viewer-bootstrap""#) else { return nil }
        let afterStart = String(html[startRange.upperBound...])
        guard let gtRange = afterStart.range(of: ">") else { return nil }
        let afterGT = String(afterStart[afterStart.index(after: gtRange.lowerBound)...])
        guard let closeRange = afterGT.range(of: "</script>") else { return nil }
        return String(afterGT[..<closeRange.lowerBound])
    }

    private func decodeJWTExpiry(from jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder == 2 { payload += "==" } else if remainder == 3 { payload += "=" }
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error = APIError.network(NSError(domain: "reelo", code: -1))
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as APIError {
                lastError = error
                // Only retry transient conditions.
                if case .rateLimited = error {} else if case .serverError = error {} else if case .network = error {} else { throw error }
                if attempt == maxRetries - 1 { break }
                try? await Task.sleep(nanoseconds: UInt64(calculateBackoff(for: attempt) * 1_000_000_000))
            } catch {
                lastError = APIError.network(error)
                if attempt == maxRetries - 1 { break }
                try? await Task.sleep(nanoseconds: UInt64(calculateBackoff(for: attempt) * 1_000_000_000))
            }
        }
        throw lastError
    }

    private func calculateBackoff(for attempt: Int) -> TimeInterval {
        min(baseBackoff * pow(2.0, Double(attempt)), 30.0)
    }
}


/// URLSessionDownloadDelegate that streams progress and hands back a stable temp file.
final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progress: (Double) -> Void
    var completion: CheckedContinuation<URL, Error>?

    init(progress: @escaping (Double) -> Void) { self.progress = progress }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(min(0.999, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            completion?.resume(throwing: VimeoAPIClient.APIError.downloadFailed(status: http.statusCode))
            completion = nil
            return
        }
        let stable = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try FileManager.default.moveItem(at: location, to: stable)
            completion?.resume(returning: stable)
        } catch {
            completion?.resume(throwing: error)
        }
        completion = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completion?.resume(throwing: VimeoAPIClient.APIError.network(error))
            completion = nil
        }
    }
}
