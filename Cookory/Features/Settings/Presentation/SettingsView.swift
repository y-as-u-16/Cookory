import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section("データ") {
                exportRow
            }
            Section("このアプリについて") {
                LabeledContent("バージョン", value: viewModel.version)
                NavigationLink("ライセンス") { LicenseView() }
                Link("プライバシーポリシー", destination: PrivacyPolicy.url)
            }
        }
        .navigationTitle("設定")
        .sheet(
            isPresented: Binding(
                get: { viewModel.exportedFile != nil },
                set: { if !$0 { viewModel.dismissExport() } }
            )
        ) {
            if let url = viewModel.exportedFile {
                ShareLink(item: url) {
                    Label("書き出したデータを共有", systemImage: "square.and.arrow.up")
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
                Text("書き出しています")
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("やり直す") { Task { await viewModel.export() } }
            }
        case .idle, .ready:
            Button {
                Task { await viewModel.export() }
            } label: {
                Label("データを書き出す", systemImage: "square.and.arrow.up")
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
        .navigationTitle("ライセンス")
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
