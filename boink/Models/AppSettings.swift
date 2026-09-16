//
//  AppSettings.swift
//  boink
//
//  Created for Vimeo Review Folder Downloader
//

import Foundation

/// App-wide settings, persisted via UserDefaults.
struct AppSettings: Codable, Equatable {
    var defaultDownloadFolder: URL?
    var maxConcurrentDownloads: Int = 3
    var preferredQuality: String = "best"
    var skipCompleted: Bool = true
    
    static let defaultsKey = "com.boink.vimeodownloader.settings"
    
    static var `default`: AppSettings {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }
        return AppSettings()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
    
    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
