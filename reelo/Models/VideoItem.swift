//
//  VideoItem.swift
//  Reelo
//
//  Model types for a single video in a Vimeo review folder.
//

import Foundation

/// Represents a single video in a Vimeo review folder.
struct VideoItem: Identifiable, Equatable {
    let id: String
    let name: String
    let link: String
    let duration: Int       // seconds
    let versionID: String?  // extracted from metadata.connections.versions.current_uri
    let videoID: String     // extracted from video.uri
    var thumbnailURL: String?

    var downloadState: DownloadState = .pending
    var downloadProgress: Double = 0.0
    var currentRendition: String?
    var errorMessage: String?

    // Cached download info (populated right before / after download)
    var fileSize: Int64 = 0

    enum DownloadState: String, Comparable {
        case pending
        case downloading
        case completed
        case failed
        case skipped

        static func < (lhs: DownloadState, rhs: DownloadState) -> Bool {
            let order: [String] = ["pending", "downloading", "failed", "skipped", "completed"]
            return (order.firstIndex(of: lhs.rawValue) ?? 0) < (order.firstIndex(of: rhs.rawValue) ?? 0)
        }
    }

    init(id: String, name: String, link: String, duration: Int, versionID: String?, videoID: String, thumbnailURL: String? = nil) {
        self.id = id
        self.name = name
        self.link = link
        self.duration = duration
        self.versionID = versionID
        self.videoID = videoID
        self.thumbnailURL = thumbnailURL
    }

    /// Parse video ID from a Vimeo URI like "/videos/123456"
    static func extractVideoID(from uri: String) -> String? {
        uri.split(separator: "/").last.map(String.init)
    }

    /// Parse version ID from a version URI like "/videos/123456/versions/789"
    static func extractVersionID(from uri: String) -> String? {
        let parts = uri.split(separator: "/")
        guard let last = parts.last else { return nil }
        let str = String(last)
        return str.isEmpty ? nil : str
    }

    /// Sanitize a filename by removing characters invalid on macOS.
    static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\*?\"<>|")
        var sanitized = name.components(separatedBy: invalid).joined(separator: " ")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.count > 200 { sanitized = String(sanitized.prefix(200)) }
        return sanitized.isEmpty ? "video" : sanitized
    }

    // NOTE: rely on the compiler-synthesized Equatable (compares ALL fields).
    // A custom id-only == makes SwiftUI treat rows as unchanged and skip
    // redrawing them, so per-row progress/state would freeze.
}

// MARK: - API response types

/// One rendition returned by the Vimeo downloads endpoint.
struct DownloadInfo: Decodable {
    let quality: String?
    let rendition: String?
    let type: String?
    let width: Int?
    let height: Int?
    let link: String
    let size: Int?
    let publicName: String?
    let sizeShort: String?

    enum CodingKeys: String, CodingKey {
        case quality, rendition, type, width, height, link, size
        case publicName = "public_name"
        case sizeShort = "size_short"
    }
}

/// Wrapper for the downloads endpoint: {"download":[ ... ]}
struct DownloadsResponse: Decodable { let download: [DownloadInfo] }

/// Paginated API response for the folder video list.
struct VimeoVideoListResponse: Decodable {
    let total: Int
    let data: [VimeoVideoEntry]
}

/// A single entry in the video list.
///
/// Vimeo's project-items endpoint wraps each entry inside a "video" object
/// (because the request asks for `video.uri`, `video.name`, ... fields),
/// while some other endpoints return those fields at the top level. This
/// custom decoder handles BOTH shapes, and decodes each field defensively so
/// one malformed entry never fails the whole page.
struct VimeoVideoEntry: Decodable {
    let uri: String
    let name: String
    let link: String
    let duration: Int
    let currentVersionURI: String?
    let thumbnailURL: String?

    private enum WrapperKeys: String, CodingKey { case video }
    private enum FieldKeys: String, CodingKey { case uri, name, link, duration, metadata, pictures }

    struct Metadata: Decodable {
        struct Connections: Decodable {
            struct Versions: Decodable {
                let currentURI: String?
                enum CodingKeys: String, CodingKey { case currentURI = "current_uri" }
            }
            let versions: Versions?
        }
        let connections: Connections?
    }

    struct Pictures: Decodable {
        struct Size: Decodable { let width: Int?; let link: String? }
        let sizes: [Size]?
        /// Pick a mid-size thumbnail (~300px wide) if available.
        var preferredLink: String? {
            guard let sizes, !sizes.isEmpty else { return nil }
            let sorted = sizes.sorted { ($0.width ?? 0) < ($1.width ?? 0) }
            let mid = sorted.first(where: { ($0.width ?? 0) >= 300 }) ?? sorted.last
            return mid?.link
        }
    }

    init(from decoder: Decoder) throws {
        let fields: KeyedDecodingContainer<FieldKeys>
        if let wrapper = try? decoder.container(keyedBy: WrapperKeys.self),
           wrapper.contains(.video),
           let nested = try? wrapper.nestedContainer(keyedBy: FieldKeys.self, forKey: .video) {
            fields = nested
        } else {
            fields = try decoder.container(keyedBy: FieldKeys.self)
        }
        self.uri = (try? fields.decode(String.self, forKey: .uri)) ?? ""
        self.name = (try? fields.decode(String.self, forKey: .name)) ?? "video"
        self.link = (try? fields.decode(String.self, forKey: .link)) ?? ""
        self.duration = (try? fields.decode(Int.self, forKey: .duration)) ?? 0
        let metadata = try? fields.decode(Metadata.self, forKey: .metadata)
        self.currentVersionURI = metadata?.connections?.versions?.currentURI
        let pictures = try? fields.decode(Pictures.self, forKey: .pictures)
        self.thumbnailURL = pictures?.preferredLink
    }
}

/// Response from the viewer-bootstrap script embedded in the review page.
struct BootstrapResponse: Decodable { let jwt: String? }
