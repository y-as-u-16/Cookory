import SwiftUI

/// 料理の作り方。材料・手順・参考リンクを残す。
struct RecipeEditorView: View {
    @State private var viewModel: RecipeEditorViewModel

    init(viewModel: RecipeEditorViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section("材料") {
                TextField("鶏もも肉 300g\n醤油 大さじ2", text: $viewModel.ingredientsDraft, axis: .vertical)
                    .lineLimit(4...12)
            }

            Section("手順") {
                TextField("1. 下味をつけて30分置く", text: $viewModel.stepsDraft, axis: .vertical)
                    .lineLimit(4...16)
            }

            Section {
                Button("保存") {
                    Task { await viewModel.save() }
                }
            }

            linkSection

            if let message = viewModel.errorMessage {
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("作り方")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var linkSection: some View {
        Section("参考リンク") {
            ForEach(viewModel.links) { link in
                HStack {
                    Link(destination: link.url) {
                        Label(link.displayName, systemImage: "link")
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.removeLink(id: link.id) }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(link.displayName) を削除")
                }
            }

            TextField("https://…", text: $viewModel.linkURLDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            TextField("名前（任意）", text: $viewModel.linkTitleDraft)

            Button("リンクを追加") {
                Task { await viewModel.addLink() }
            }
            .disabled(!viewModel.canAddLink)
        }
    }
}
