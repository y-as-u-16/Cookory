import SwiftUI

/// 料理の作り方。材料・手順・参考リンクを残す。
struct RecipeEditorView: View {
    @State private var viewModel: RecipeEditorViewModel

    init(viewModel: RecipeEditorViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section(String(localized: L10n.recipeIngredients)) {
                TextField("", text: $viewModel.ingredientsDraft, axis: .vertical)
                    .lineLimit(4...12)
            }

            Section(String(localized: L10n.recipeSteps)) {
                TextField("", text: $viewModel.stepsDraft, axis: .vertical)
                    .lineLimit(4...16)
            }

            Section {
                Button(String(localized: L10n.recipeSave)) {
                    Task { await viewModel.save() }
                }
            }

            linkSection

            if let message = viewModel.errorMessage {
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle(Text(L10n.recipeTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var linkSection: some View {
        Section(String(localized: L10n.recipeLinks)) {
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
                    .accessibilityLabel(link.displayName)
                }
            }

            TextField("https://…", text: $viewModel.linkURLDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            TextField(String(localized: L10n.recipeLinkName), text: $viewModel.linkTitleDraft)

            Button(String(localized: L10n.recipeAddLink)) {
                Task { await viewModel.addLink() }
            }
            .disabled(!viewModel.canAddLink)
        }
    }
}
