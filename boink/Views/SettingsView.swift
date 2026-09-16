//
//  SettingsView.swift
//  Reelo
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Binding var settings: AppSettings
    var onFolderChange: (URL?) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ReeloLogo(size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ayarlar").font(.title3.weight(.semibold))
                    Text("Reelo tercihleri").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Download folder
                    settingsCard(icon: "folder.fill", title: "İndirme klasörü") {
                        HStack {
                            Text(settings.defaultDownloadFolder?.path ?? "Varsayılan: İndirilenler")
                                .font(.callout).foregroundStyle(settings.defaultDownloadFolder == nil ? .secondary : .primary)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Değiştir", action: chooseFolder)
                        }
                    }

                    // Quality
                    settingsCard(icon: "slider.horizontal.3", title: "Varsayılan kalite") {
                        Picker("", selection: $settings.preferredQuality) {
                            Text("En iyi").tag("best")
                            Text("1080p").tag("1080p")
                            Text("720p").tag("720p")
                            Text("480p").tag("480p")
                            Text("360p").tag("360p")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // Concurrency
                    settingsCard(icon: "arrow.down.circle", title: "Aynı anda indirme") {
                        Stepper(value: $settings.maxConcurrentDownloads, in: 1...10) {
                            HStack {
                                Text("Paralel indirme sayısı")
                                Spacer()
                                Text("\(settings.maxConcurrentDownloads)")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(Brand.accent)
                            }
                        }
                    }

                    // Skip completed
                    settingsCard(icon: "checkmark.circle", title: "Devam etme") {
                        Toggle(isOn: $settings.skipCompleted) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zaten indirilenleri atla")
                                Text("Aynı klasörü tekrar girdiğinde tamamlananlar atlanır.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Brand.accent)
                    }

                    // About
                    settingsCard(icon: "info.circle", title: "Hakkında") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Brand.name) \(appVersion)")
                            Text(Brand.tagline).font(.caption).foregroundStyle(.secondary)
                            Text("Saf Swift + SwiftUI · harici bağımlılık yok")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
            }

            Divider()
            HStack {
                Spacer()
                Button("Tamam") { settings.save(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent).tint(Brand.accent)
            }
            .padding(14)
        }
        .frame(width: 460, height: 560)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }

    @ViewBuilder
    private func settingsCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(Brand.accent).frame(width: 18)
                Text(title).font(.headline)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.15)))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seç"
        if let current = settings.defaultDownloadFolder { panel.directoryURL = current }
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultDownloadFolder = url
            settings.save()
            onFolderChange(url)
        }
    }
}

#Preview { SettingsView(settings: .constant(AppSettings.default)) }
