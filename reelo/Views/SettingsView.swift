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

    private var lang: AppLanguage { settings.appLanguage }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ReeloLogo(size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(lang.t("settings.title")).font(.title3.weight(.semibold))
                    Text(lang.t("settings.subtitle")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Download folder
                    settingsCard(icon: "folder.fill", title: lang.t("settings.downloadFolder")) {
                        HStack {
                            Text(settings.defaultDownloadFolder?.path ?? lang.t("settings.defaultFolder"))
                                .font(.callout).foregroundStyle(settings.defaultDownloadFolder == nil ? .secondary : .primary)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button(lang.t("settings.change"), action: chooseFolder)
                        }
                    }

                    // Quality
                    settingsCard(icon: "slider.horizontal.3", title: lang.t("settings.quality")) {
                        Picker("", selection: $settings.preferredQuality) {
                            Text(lang.t("common.best")).tag("best")
                            Text("1080p").tag("1080p")
                            Text("720p").tag("720p")
                            Text("480p").tag("480p")
                            Text("360p").tag("360p")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // Concurrency
                    settingsCard(icon: "arrow.down.circle", title: lang.t("settings.concurrency")) {
                        Stepper(value: $settings.maxConcurrentDownloads, in: 1...10) {
                            HStack {
                                Text(lang.t("settings.concurrentCount"))
                                Spacer()
                                Text("\(settings.maxConcurrentDownloads)")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(Brand.accent)
                            }
                        }
                    }

                    // Skip completed
                    settingsCard(icon: "checkmark.circle", title: lang.t("settings.resume")) {
                        Toggle(isOn: $settings.skipCompleted) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.t("settings.skip"))
                                Text(lang.t("settings.skipSubtitle"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Brand.accent)
                    }

                    // Language
                    settingsCard(icon: "globe", title: lang.t("settings.language")) {
                        HStack {
                            Text(lang.t("settings.languageSubtitle"))
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Picker(lang.t("settings.language"), selection: $settings.language) {
                                ForEach(AppLanguage.allCases) { l in
                                    Text("\(l.flagEmoji) \(l.displayName)").tag(l.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .onChange(of: settings.language) {
                                settings.save()
                            }
                        }
                    }

                    // About
                    settingsCard(icon: "info.circle", title: lang.t("settings.about")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Brand.name) \(appVersion)")
                            Text(lang.t("app.tagline")).font(.caption).foregroundStyle(.secondary)
                            Text(lang.t("settings.aboutStack"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
            }

            Divider()
            HStack {
                Spacer()
                Button(lang.t("common.done")) { settings.save(); dismiss() }
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
        panel.prompt = lang.t("common.choose")
        if let current = settings.defaultDownloadFolder { panel.directoryURL = current }
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultDownloadFolder = url
            settings.save()
            onFolderChange(url)
        }
    }
}

#Preview { SettingsView(settings: .constant(AppSettings.default)) }
