//
//  ContentView.swift
//  Reelo
//

import SwiftUI
import AppKit

// MARK: - Brand

enum Brand {
    static let name = "Reelo"
    static let tagline = "Vimeo review klasörü indirici"
    static let accent = Color(red: 0.42, green: 0.36, blue: 0.90)
    static let accent2 = Color(red: 0.63, green: 0.32, blue: 0.86)
    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// The app logo: a rounded gradient tile with a filmstrip + download arrow.
struct ReeloLogo: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Brand.gradient)
                .shadow(color: Brand.accent.opacity(0.35), radius: size * 0.12, y: size * 0.06)
            Image(systemName: "film.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .offset(y: -size * 0.06)
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(.white)
                .background(Circle().fill(Brand.accent2).frame(width: size * 0.30, height: size * 0.30))
                .offset(x: size * 0.24, y: size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main view

struct ContentView: View {
    @State private var reviewURL: String = ""
    @State private var downloadFolder: URL?
    @State private var preferredQuality: String = "best"
    @State private var downloadManager: DownloadManager?
    @State private var showSettings = false
    @State private var settings = AppSettings.default

    private var isDownloading: Bool { downloadManager?.isDownloading ?? false }
    private var isValidLink: Bool { Self.parseIDs(from: reviewURL) != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controlPanel
            if let err = downloadManager?.errorMessage {
                errorBanner(err, code: downloadManager?.errorCode)
            }
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $settings) { newFolder in
                if let newFolder { downloadFolder = newFolder }
            }
        }
        .onAppear {
            if downloadFolder == nil {
                downloadFolder = settings.defaultDownloadFolder
                    ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ReeloLogo(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(Brand.name).font(.system(size: 20, weight: .bold))
                Text(Brand.tagline).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 15))
            }
            .buttonStyle(.borderless)
            .help("Ayarlar")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: Control panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link").foregroundStyle(.secondary)
                TextField("https://vimeo.com/reviews/…/users/…/folders/…", text: $reviewURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .disabled(isDownloading)
                if !reviewURL.isEmpty {
                    Image(systemName: isValidLink ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(isValidLink ? .green : .orange)
                        .help(isValidLink ? "Geçerli review linki" : "Link biçimi beklenenden farklı")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.25)))

            HStack(spacing: 10) {
                // Download location (click to choose)
                Button(action: chooseFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill").foregroundStyle(Brand.accent)
                        Text(downloadFolder?.lastPathComponent ?? "Klasör seç")
                            .lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help(downloadFolder?.path ?? "İndirme klasörü seçilmedi")
                .disabled(isDownloading)

                Picker("", selection: $preferredQuality) {
                    Text("En iyi").tag("best")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                    Text("480p").tag("480p")
                    Text("360p").tag("360p")
                }
                .labelsHidden()
                .frame(width: 110)
                .disabled(isDownloading)

                Spacer()

                if isDownloading {
                    Button(role: .destructive, action: handleCancel) {
                        Label("İptal", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button(action: handleDownload) {
                        Label("İndir", systemImage: "arrow.down.circle.fill").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent).tint(Brand.accent)
                    .disabled(!isValidLink || downloadFolder == nil)
                }
            }

            if let m = downloadManager, m.isDownloading || m.overallProgress > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: m.overallProgress).tint(Brand.accent)
                    HStack {
                        if m.isPreparing { ProgressView().controlSize(.small).scaleEffect(0.7) }
                        Text(m.statusMessage).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if !m.videos.isEmpty {
                            Text("\(m.completedCount)/\(m.videos.count)")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private func errorBanner(_ message: String, code: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(message).font(.callout).textSelection(.enabled)
                if let code {
                    Text("Hata kodu: \(code)").font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.35)))
        .padding(.horizontal, 18).padding(.bottom, 10)
    }

    // MARK: Content area

    @ViewBuilder private var content: some View {
        if let m = downloadManager, !m.videos.isEmpty {
            VideoListView(videos: m.videos)
        } else if let m = downloadManager, m.isPreparing {
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(m.statusMessage).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView()
        }
    }

    // MARK: Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seç"
        panel.message = "Videoların indirileceği klasörü seç"
        if let current = downloadFolder { panel.directoryURL = current }
        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url
            settings.defaultDownloadFolder = url
            settings.save()
        }
    }

    private func handleDownload() {
        guard let ids = Self.parseIDs(from: reviewURL), let url = URL(string: reviewURL) else { return }
        guard let folder = downloadFolder else { chooseFolder(); return }
        let manager = DownloadManager(reviewID: ids.review, folderID: ids.folder, settings: settings)
        downloadManager = manager
        manager.startDownloads(reviewURL: url, downloadFolder: folder, preferredQuality: preferredQuality)
    }

    private func handleCancel() {
        downloadManager?.cancelDownloads()
    }

    // MARK: Link parsing

    static func parseIDs(from string: String) -> (review: String, user: String, folder: String)? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https" else { return nil }
        let c = url.pathComponents
        guard c.count >= 7, c[1] == "reviews", c[3] == "users", c[5] == "folders" else { return nil }
        return (c[2], c[4], c[6])
    }
}

// MARK: - Video list

struct VideoListView: View {
    let videos: [VideoItem]
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(videos) { video in
                    VideoRow(video: video)
                    Divider().padding(.leading, 84)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct VideoRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 8) {
                    Text(formatDuration(video.duration)).font(.caption).foregroundStyle(.secondary)
                    if let r = video.currentRendition { Text("· \(r)").font(.caption).foregroundStyle(.secondary) }
                    if video.fileSize > 0 { Text("· \(formatBytes(video.fileSize))").font(.caption).foregroundStyle(.secondary) }
                }
                if video.downloadState == .failed, let e = video.errorMessage {
                    Text(e).font(.caption2).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            statusIcon
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)).frame(width: 60, height: 40)
            if let s = video.thumbnailURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Image(systemName: "film").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 60, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "film").foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 40)
    }

    @ViewBuilder private var statusIcon: some View {
        switch video.downloadState {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        case .downloading:
            CircularProgressRing(progress: video.downloadProgress)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .pending:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func formatBytes(_ b: Int64) -> String {
        let mb = Double(b) / 1_048_576.0
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Circular progress ring

/// Downloading indicator: a blue ring that slowly spins and fills as the
/// download progresses (pending = dashed circle, done = green check).
struct CircularProgressRing: View {
    let progress: Double
    @State private var spin = false
    private let ringBlue = Color(red: 0.20, green: 0.56, blue: 0.98)

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.05, min(progress, 1.0)))
                .stroke(ringBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spin)
        }
        .frame(width: 20, height: 20)
        .onAppear { spin = true }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 18) {
            ReeloLogo(size: 76)
            Text("Vimeo review linkini yapıştır").font(.title3.weight(.semibold))
            Text("Herkese açık, parolasız Vimeo review klasörlerindeki videoları\ntoplu olarak indirir.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("vimeo.com/reviews/{review_id}/users/{user_id}/folders/{folder_id}")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview { ContentView() }
