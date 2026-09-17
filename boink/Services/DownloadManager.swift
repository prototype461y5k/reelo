//
//  DownloadManager.swift
//  Reelo
//
//  Observable view-model that orchestrates the whole download lifecycle.
//

import Foundation

@Observable
@MainActor
final class DownloadManager {

    // MARK: - Published state
    var videos: [VideoItem] = []
    var isDownloading = false
    var isPreparing = false
    var overallProgress: Double = 0.0
    var errorMessage: String?
    var errorCode: String?
    var statusMessage: String = ""
    var folderName: String?
    var completedCount: Int = 0
    var failedCount: Int = 0

    // MARK: - Internal
    private var activity: NSObjectProtocol?
    private var apiClient: VimeoAPIClient
    private var archive: DownloadArchive?
    private let appSettings: AppSettings
    private let maxConcurrent: Int

    init(apiClient: VimeoAPIClient = VimeoAPIClient(), reviewID: String, folderID: String, settings: AppSettings = .default) {
        self.apiClient = apiClient
        self.archive = DownloadArchive(reviewID: reviewID, folderID: folderID)
        self.appSettings = settings
        self.maxConcurrent = max(1, min(settings.maxConcurrentDownloads, 10))
    }

    // MARK: - Public

    func startDownloads(reviewURL: URL, downloadFolder: URL, preferredQuality: String, onComplete: @escaping () -> Void = {}) {
        guard !isDownloading else { return }
        isDownloading = true
        isPreparing = true
        overallProgress = 0
        completedCount = 0
        failedCount = 0
        errorMessage = nil
        errorCode = nil
        statusMessage = "Hazırlanıyor…"
        startSystemWakeActivity()

        Task {
            do {
                try await runDownloads(reviewURL: reviewURL, downloadFolder: downloadFolder, preferredQuality: preferredQuality)
                if failedCount == 0 {
                    statusMessage = "Tüm indirmeler tamamlandı 🎉"
                } else {
                    statusMessage = "\(completedCount) indirildi, \(failedCount) başarısız."
                }
            } catch let e as VimeoAPIClient.APIError {
                errorMessage = e.errorDescription
                errorCode = e.code
                statusMessage = "Hata: \(e.errorDescription ?? "Bilinmeyen")"
            } catch {
                errorMessage = error.localizedDescription
                errorCode = "REELO-ERR"
                statusMessage = "Hata: \(error.localizedDescription)"
            }
            isDownloading = false
            isPreparing = false
            stopSystemWakeActivity()
            onComplete()
        }
    }

    func cancelDownloads() {
        isDownloading = false
        isPreparing = false
        stopSystemWakeActivity()
        apiClient = VimeoAPIClient()
        statusMessage = "İndirme iptal edildi."
    }

    // MARK: - Orchestration

    private func runDownloads(reviewURL: URL, downloadFolder: URL, preferredQuality: String) async throws {
        let (reviewID, userID, folderID) = try parseReviewURL(reviewURL)

        // Make sure the destination exists.
        try? FileManager.default.createDirectory(at: downloadFolder, withIntermediateDirectories: true)

        statusMessage = "Video listesi alınıyor…"
        _ = try await apiClient.fetchBootstrapJWT(from: reviewURL)
        let allVideos = try await apiClient.fetchAllVideos(userID: userID, folderID: folderID, reviewID: reviewID, baseURL: reviewURL)

        // A video counts as already-downloaded only if the archive says so
        // AND the file still exists on disk. If the user deleted a file,
        // treat it as pending, download it again, and drop the stale entry.
        func downloadedFileExists(for video: VideoItem) -> Bool {
            let filename = VideoItem.sanitizeFilename(video.name) + ".mp4"
            let dest = downloadFolder.appendingPathComponent(filename)
            return FileManager.default.fileExists(atPath: dest.path)
        }

        let archivedIDs = archive?.completedIDs() ?? []
        var completedIDs = Set<String>()
        for video in allVideos where archivedIDs.contains(video.id) {
            if downloadedFileExists(for: video) {
                completedIDs.insert(video.id)
            } else {
                archive?.remove(video.id)
            }
        }

        let pending = allVideos.filter { !completedIDs.contains($0.id) }

        // Show the whole list; mark only the ones truly present on disk as done.
        var shown = allVideos
        for i in shown.indices where completedIDs.contains(shown[i].id) {
            shown[i].downloadState = .completed
            shown[i].downloadProgress = 1.0
        }
        videos = shown
        completedCount = completedIDs.count
        isPreparing = false

        if pending.isEmpty {
            statusMessage = "Bu klasördeki tüm videolar zaten indirilmiş."
            overallProgress = 1.0
            return
        }

        statusMessage = "\(pending.count) video indiriliyor…"
        try await downloadWithConcurrencyControl(videos: pending, reviewURL: reviewURL, downloadFolder: downloadFolder, reviewID: reviewID, preferredQuality: preferredQuality)
    }

    private func downloadWithConcurrencyControl(videos toDownload: [VideoItem], reviewURL: URL, downloadFolder: URL, reviewID: String, preferredQuality: String) async throws {
        // Split the work into per-worker buckets up front. This keeps the
        // downloads concurrent without any shared mutable state or a lock
        // (NSLock is not safe to use across async suspension points).
        let workerCount = max(1, min(maxConcurrent, toDownload.count))
        var buckets: [[VideoItem]] = Array(repeating: [], count: workerCount)
        for (i, video) in toDownload.enumerated() {
            buckets[i % workerCount].append(video)
        }

        await withTaskGroup(of: Void.self) { group in
            for bucket in buckets {
                group.addTask { [weak self] in
                    guard let self else { return }
                    for video in bucket {
                        let stillRunning = await self.isDownloading
                        if !stillRunning { return }
                        do {
                            try await self.downloadSingleVideo(video: video, reviewURL: reviewURL, downloadFolder: downloadFolder, reviewID: reviewID, preferredQuality: preferredQuality)
                        } catch {
                            await self.markFailed(video: video, error: error)
                        }
                    }
                }
            }
        }
    }

    private func downloadSingleVideo(video: VideoItem, reviewURL: URL, downloadFolder: URL, reviewID: String, preferredQuality: String) async throws {
        setState(video.id, .downloading, progress: 0)
        statusMessage = "İndiriliyor: \(video.name)"

        let jwt = try await apiClient.ensureJWT(from: reviewURL)
        let info = try await apiClient.fetchDownloadURL(video: video, reviewID: reviewID, jwt: jwt, preferredQuality: preferredQuality)

        let filename = VideoItem.sanitizeFilename(video.name) + ".mp4"
        let destination = downloadFolder.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destination.path) {
            if let idx = index(of: video.id) {
                videos[idx].downloadState = .completed
                videos[idx].downloadProgress = 1.0
                videos[idx].currentRendition = info.rendition
                videos[idx].fileSize = info.size
            }
            archive?.markCompleted(video.id)
            completedCount += 1
            updateOverallProgress()
            return
        }

        _ = try await apiClient.downloadFile(from: info.url, to: destination, expectedSize: info.size) { [weak self] progress in
            Task { @MainActor in
                guard let self, let idx = self.index(of: video.id) else { return }
                self.videos[idx].downloadProgress = progress
                self.videos[idx].currentRendition = info.rendition
                self.videos[idx].fileSize = info.size
            }
        }

        if let idx = index(of: video.id) {
            videos[idx].downloadState = .completed
            videos[idx].downloadProgress = 1.0
        }
        archive?.markCompleted(video.id)
        completedCount += 1
        updateOverallProgress()
    }

    // MARK: - Helpers

    private func index(of id: String) -> Int? { videos.firstIndex { $0.id == id } }

    private func setState(_ id: String, _ state: VideoItem.DownloadState, progress: Double? = nil) {
        guard let idx = index(of: id) else { return }
        videos[idx].downloadState = state
        if let progress { videos[idx].downloadProgress = progress }
    }

    private func markFailed(video: VideoItem, error: Error) {
        if let idx = index(of: video.id) {
            videos[idx].downloadState = .failed
            if let e = error as? VimeoAPIClient.APIError {
                videos[idx].errorMessage = "\(e.errorDescription ?? "Hata") (\(e.code))"
            } else {
                videos[idx].errorMessage = error.localizedDescription
            }
        }
        failedCount += 1
        updateOverallProgress()
    }

    private func updateOverallProgress() {
        let total = videos.count
        guard total > 0 else { return }
        overallProgress = Double(completedCount + failedCount) / Double(total)
    }

    private func startSystemWakeActivity() {
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], reason: "Reelo: indirme sürüyor")
    }

    private func stopSystemWakeActivity() {
        if let act = activity { ProcessInfo.processInfo.endActivity(act); activity = nil }
    }

    /// Parse review URL → (reviewID, userID, folderID).
    /// Expected: https://vimeo.com/reviews/{review_id}/users/{user_id}/folders/{folder_id}
    private func parseReviewURL(_ url: URL) throws -> (String, String, String) {
        let c = url.pathComponents
        guard c.count >= 7, c[1] == "reviews", c[3] == "users", c[5] == "folders" else {
            throw VimeoAPIClient.APIError.badLinkFormat
        }
        return (c[2], c[4], c[6])
    }
}
