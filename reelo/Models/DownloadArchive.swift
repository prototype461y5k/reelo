//
//  DownloadArchive.swift
//  boink
//
//  Created for Vimeo Review Folder Downloader
//

import Foundation

/// Persists completed download IDs so that resumable downloads work
/// across app restarts and repeated folder link entries.
class DownloadArchive {
    private let archiveURL: URL
    
    /// Initialize with a specific review/folder identifier.
    /// The archive is stored in the app's Application Support directory.
    init(reviewID: String, folderID: String) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let archiveDir = folder.appendingPathComponent("boink_archives", isDirectory: true)
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        
        // Unique key per review+folder combo
        let key = "\(reviewID)_\(folderID)"
        self.archiveURL = archiveDir.appendingPathComponent("\(key).json")
    }
    
    /// Load the set of already-completed video IDs.
    func completedIDs() -> Set<String> {
        guard let data = try? Data(contentsOf: archiveURL),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(ids)
    }
    
    /// Mark a video ID as completed.
    func markCompleted(_ id: String) {
        var ids = completedIDs()
        ids.insert(id)
        save(ids: Array(ids))
    }
    
    /// Clear the entire archive (e.g. on retry-all).
    func clear() {
        try? FileManager.default.removeItem(at: archiveURL)
    }

    /// Remove a single video ID from the archive. Used when the user
    /// deleted the downloaded file and we want it to download again.
    func remove(_ id: String) {
        var ids = completedIDs()
        ids.remove(id)
        save(ids: Array(ids))
    }
    
    private func save(ids: [String]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(ids) {
            try? data.write(to: archiveURL)
        }
    }
    
    /// Total completed count
    var completedCount: Int {
        return completedIDs().count
    }
}
