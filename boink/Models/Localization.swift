//
//  Localization.swift
//  Reelo
//
//  In-code translation catalog and UI language selection.
//
//  English is the app's default language. Any key that a language does not
//  have a translation for automatically falls back to English.
//
//  HOW TO ADD A NEW LANGUAGE:
//    1. Add a case to `AppLanguage` below (rawValue = language code, e.g. "de").
//    2. Give it a `displayName` (the name of the language, in that language)
//       and an optional flag emoji.
//    3. Add its entries in `L10n.catalog`. You only need to translate the
//       keys you care about — everything else stays English.
//
//  HOW TO ADD A NEW TRANSLATABLE STRING:
//    Add one entry to `L10n.catalog`. Values may contain `String(format:)`
//    placeholders: `%d` for integers, `%@` for anything else.
//

import Foundation

/// A language the Reelo interface can be shown in.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    /// Name of the language, written in the language itself.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }

    var flagEmoji: String {
        switch self {
        case .english: return "🇬🇧"
        case .turkish: return "🇹🇷"
        }
    }

    /// Translate `key` into this language.
    /// Falls back to English, then to the key itself — never returns empty.
    func t(_ key: String) -> String {
        L10n.catalog[key]?[rawValue] ?? L10n.catalog[key]?["en"] ?? key
    }
}

/// The central translation table.
///
/// Keys are semantic and stable. Each value maps a language code to its
/// text. The `en` entry is the fallback used by every other language.
enum L10n {
    static let catalog: [String: [String: String]] = [

        // MARK: Common
        "common.settings":    ["en": "Settings", "tr": "Ayarlar"],
        "common.choose":      ["en": "Choose", "tr": "Seç"],
        "common.cancel":      ["en": "Cancel", "tr": "İptal"],
        "common.done":        ["en": "Done", "tr": "Tamam"],
        "common.best":        ["en": "Best", "tr": "En iyi"],

        // MARK: App
        "app.tagline":        ["en": "Vimeo review folder downloader", "tr": "Vimeo review klasörü indirici"],

        // MARK: Main window
        "main.validLink":     ["en": "Valid review link", "tr": "Geçerli review linki"],
        "main.invalidLink":   ["en": "Link format doesn't match", "tr": "Link biçimi beklenenden farklı"],
        "main.chooseFolder":  ["en": "Choose folder", "tr": "Klasör seç"],
        "main.noFolder":      ["en": "No download folder selected", "tr": "İndirme klasörü seçilmedi"],
        "main.download":      ["en": "Download", "tr": "İndir"],
        "main.errorCode":     ["en": "Error code: %@", "tr": "Hata kodu: %@"],
        "main.folderPrompt":  ["en": "Choose the folder where videos will be downloaded", "tr": "Videoların indirileceği klasörü seç"],
        "empty.title":        ["en": "Paste your Vimeo review link", "tr": "Vimeo review linkini yapıştır"],
        "empty.subtitle":     ["en": "Batch-downloads videos from public, password-free Vimeo review folders.",
                                "tr": "Herkese açık, parolasız Vimeo review klasörlerindeki videoları\ntoplu olarak indirir."],

        // MARK: Settings
        "settings.title":             ["en": "Settings", "tr": "Ayarlar"],
        "settings.subtitle":          ["en": "Reelo preferences", "tr": "Reelo tercihleri"],
        "settings.downloadFolder":    ["en": "Download folder", "tr": "İndirme klasörü"],
        "settings.defaultFolder":     ["en": "Default: Downloads", "tr": "Varsayılan: İndirilenler"],
        "settings.change":            ["en": "Change", "tr": "Değiştir"],
        "settings.quality":           ["en": "Default quality", "tr": "Varsayılan kalite"],
        "settings.concurrency":       ["en": "Concurrent downloads", "tr": "Aynı anda indirme"],
        "settings.concurrentCount":   ["en": "Number of parallel downloads", "tr": "Paralel indirme sayısı"],
        "settings.resume":            ["en": "Resuming", "tr": "Devam etme"],
        "settings.skip":              ["en": "Skip already downloaded", "tr": "Zaten indirilenleri atla"],
        "settings.skipSubtitle":      ["en": "When you enter the same folder again, completed downloads are skipped.",
                                        "tr": "Aynı klasörü tekrar girdiğinde tamamlananlar atlanır."],
        "settings.language":          ["en": "Language", "tr": "Dil"],
        "settings.languageSubtitle":  ["en": "Language of the app interface.", "tr": "Uygulama arayüzünün dili."],
        "settings.about":             ["en": "About", "tr": "Hakkında"],
        "settings.aboutStack":        ["en": "Pure Swift + SwiftUI · no external dependencies", "tr": "Saf Swift + SwiftUI · harici bağımlılık yok"],

        // MARK: Download status messages
        "dl.preparing":               ["en": "Preparing…", "tr": "Hazırlanıyor…"],
        "dl.allComplete":             ["en": "All downloads complete 🎉", "tr": "Tüm indirmeler tamamlandı 🎉"],
        "dl.partial":                 ["en": "%d downloaded, %d failed.", "tr": "%d indirildi, %d başarısız."],
        "dl.error":                   ["en": "Error: %@", "tr": "Hata: %@"],
        "dl.cancelled":               ["en": "Download cancelled.", "tr": "İndirme iptal edildi."],
        "dl.fetchingList":            ["en": "Fetching video list…", "tr": "Video listesi alınıyor…"],
        "dl.allAlreadyDownloaded":    ["en": "All videos in this folder are already downloaded.",
                                        "tr": "Bu klasördeki tüm videolar zaten indirilmiş."],
        "dl.downloadingCount":        ["en": "Downloading %d videos…", "tr": "%d video indiriliyor…"],
        "dl.downloading":             ["en": "Downloading: %@", "tr": "İndiriliyor: %@"],
        "dl.unknown":                 ["en": "Unknown", "tr": "Bilinmeyen"],
        "dl.errorShort":              ["en": "Error", "tr": "Hata"],

        // MARK: API errors
        "err.invalidURL":             ["en": "Invalid link.", "tr": "Geçersiz bağlantı."],
        "err.badLinkFormat":          ["en": "Link format not recognized. Correct format: vimeo.com/reviews/{review}/users/{user}/folders/{folder}",
                                        "tr": "Bağlantı biçimi tanınmadı. Doğru biçim: vimeo.com/reviews/{review}/users/{user}/folders/{folder}"],
        "err.pageNotReachable":       ["en": "Review page could not be reached (HTTP %@). Check your internet connection and the link.",
                                        "tr": "Review sayfasına ulaşılamadı (HTTP %@). İnternet bağlantını ve linki kontrol et."],
        "err.bootstrapMissing":       ["en": "Page structure could not be recognized. Vimeo may have changed the page layout.",
                                        "tr": "Sayfa yapısı tanınamadı. Vimeo sayfa düzenini değiştirmiş olabilir."],
        "err.jwtMissing":             ["en": "Session key (JWT) could not be obtained. Is this a public review link?",
                                        "tr": "Oturum anahtarı (JWT) alınamadı. Link herkese açık bir review linki mi?"],
        "err.notAuthorized":          ["en": "Access denied (HTTP %@). This review link must be public and password-free.",
                                        "tr": "Yetki reddedildi (HTTP %@). Bu review linki herkese açık ve parolasız olmalı."],
        "err.notFound":               ["en": "Folder or review not found (HTTP 404). The link may have expired or been deleted.",
                                        "tr": "Klasör veya review bulunamadı (HTTP 404). Link süresi dolmuş ya da silinmiş olabilir."],
        "err.rateLimitedWait":        ["en": "Vimeo rate limit: waiting %d s…", "tr": "Vimeo hız sınırı: %d sn bekleniyor…"],
        "err.rateLimited":            ["en": "Hit the Vimeo rate limit, waiting…", "tr": "Vimeo hız sınırına takıldı, bekleniyor…"],
        "err.serverError":            ["en": "Vimeo server error (HTTP %@). Try again in a moment.",
                                        "tr": "Vimeo sunucu hatası (HTTP %@). Biraz sonra tekrar dene."],
        "err.invalidJSON":            ["en": "Response could not be parsed. (%@)", "tr": "Yanıt çözümlenemedi. (%@)"],
        "err.noVersion":              ["en": "Video version not found.", "tr": "Video sürümü bulunamadı."],
        "err.noDownload":             ["en": "No download link found for this video (downloads may be disabled).",
                                        "tr": "Bu video için indirme bağlantısı bulunamadı (indirme kapalı olabilir)."],
        "err.downloadFailed":         ["en": "Download failed (HTTP %@).", "tr": "İndirme başarısız (HTTP %@)."],
        "err.diskWrite":              ["en": "File could not be written to disk: %@", "tr": "Dosya diske yazılamadı: %@"],
        "err.network":                ["en": "Network error: %@", "tr": "Ağ hatası: %@"]
    ]
}