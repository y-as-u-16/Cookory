import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(AppSettings.self) private var appSettings

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        @Bindable var settings = appSettings
        List {
            Section(String(localized: L10n.settingsDataSection)) {
                exportRow
            }
            Section(String(localized: L10n.settingsAppearanceSection)) {
                Picker(String(localized: L10n.settingsTheme), selection: $settings.theme) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Picker(String(localized: L10n.settingsLanguage), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
            }
            Section(String(localized: L10n.settingsAboutSection)) {
                LabeledContent(String(localized: L10n.settingsVersion), value: viewModel.version)
                NavigationLink(String(localized: L10n.settingsLicense)) { LicenseView() }
                Link(String(localized: L10n.settingsPrivacy), destination: PrivacyPolicy.url)
            }
        }
        .navigationTitle(Text(L10n.settingsTitle))
        .sheet(
            isPresented: Binding(
                get: { viewModel.exportedFile != nil },
                set: { if !$0 { viewModel.dismissExport() } }
            )
        ) {
            if let url = viewModel.exportedFile {
                ShareLink(item: url) {
                    Label(L10n.settingsShareExport, systemImage: "square.and.arrow.up")
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private var exportRow: some View {
        switch viewModel.exportState {
        case .exporting(let progress):
            ProgressView(value: progress) {
                Text(L10n.settingsExporting)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button(String(localized: L10n.captureRetry)) { Task { await viewModel.export() } }
            }
        case .idle, .ready:
            Button {
                Task { await viewModel.export() }
            } label: {
                Label(L10n.settingsExport, systemImage: "square.and.arrow.up")
            }
        }
    }
}

/// プライバシーポリシーの掲載先。App Store 申請に必須。
enum PrivacyPolicy {
    static let url = URL(string: "https://github.com/y-as-u-16/Cookory/blob/main/PRIVACY.md")!
}

private struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text(LicenseText.content)
                .font(.footnote.monospaced())
                .padding()
        }
        .navigationTitle(Text(L10n.settingsLicense))
    }
}

private enum LicenseText {
    static let content = """
    Cookory

    Copyright (c) 2026 y-as-u-16

    MIT License. 全文はリポジトリの LICENSE を参照してください。
    https://github.com/y-as-u-16/Cookory

    本アプリは外部のサードパーティライブラリを使用していません。
    """
}
