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
    /// Raw value of `AppLanguage` (e.g. "en", "tr"). English is the default.
    var language: String = AppLanguage.english.rawValue

    init(defaultDownloadFolder: URL? = nil,
         maxConcurrentDownloads: Int = 3,
         preferredQuality: String = "best",
         skipCompleted: Bool = true,
         language: String = AppLanguage.english.rawValue) {
        self.defaultDownloadFolder = defaultDownloadFolder
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.preferredQuality = preferredQuality
        self.skipCompleted = skipCompleted
        self.language = language
    }

    static let defaultsKey = "com.boink.vimeodownloader.settings"

    /// The currently selected UI language, validated against known languages.
    var appLanguage: AppLanguage {
        AppLanguage(rawValue: language) ?? .english
    }
    
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

    // Decoding is defensive: a missing key (e.g. settings saved by an older
    // version of the app that didn't have `language`) falls back to the
    // default value instead of failing the whole decode. This keeps user
    // settings intact across app updates, and keeps working if future
    // versions add even more fields.
    enum CodingKeys: String, CodingKey {
        case defaultDownloadFolder, maxConcurrentDownloads, preferredQuality, skipCompleted, language
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultDownloadFolder = try c.decodeIfPresent(URL.self, forKey: .defaultDownloadFolder)
        maxConcurrentDownloads = try c.decodeIfPresent(Int.self, forKey: .maxConcurrentDownloads) ?? 3
        preferredQuality = try c.decodeIfPresent(String.self, forKey: .preferredQuality) ?? "best"
        skipCompleted = try c.decodeIfPresent(Bool.self, forKey: .skipCompleted) ?? true
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? AppLanguage.english.rawValue
    }
}
