import SwiftUI

/// 料理の作り方。材料・手順・参考リンクを残す。
struct RecipeEditorView: View {
    @State private var viewModel: RecipeEditorViewModel

    init(viewModel: RecipeEditorViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            RecipeContentFields(draft: viewModel.draft)

            Section {
                Button(String(localized: L10n.recipeSave)) {
                    Task { await viewModel.save() }
                }
            }

            RecipeLinkFields(
                draft: viewModel.draft,
                onAdd: { Task { await viewModel.addLink() } },
                onRemove: { id in Task { await viewModel.removeLink(id: id) } }
            )

            if let message = viewModel.errorMessage {
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle(Text(L10n.recipeTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// 材料と手順。記録画面とこの画面で同じ書きかけを編集する。
private struct RecipeContentFields: View {
    @Bindable var draft: DishRecipeDraft

    var body: some View {
        Section(String(localized: L10n.recipeIngredients)) {
            TextField("", text: $draft.ingredients, axis: .vertical)
                .lineLimit(4...12)
        }

        Section(String(localized: L10n.recipeSteps)) {
            TextField("", text: $draft.steps, axis: .vertical)
                .lineLimit(4...16)
        }
    }
}

private struct RecipeLinkFields: View {
    @Bindable var draft: DishRecipeDraft

    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        Section(String(localized: L10n.recipeLinks)) {
            ForEach(draft.links) { link in
                HStack {
                    Link(destination: link.url) {
                        Label(link.displayName, systemImage: "link")
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        onRemove(link.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(link.displayName)
                }
            }

            TextField("https://…", text: $draft.linkURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)

            Button(String(localized: L10n.recipeAddLink), action: onAdd)
                .disabled(!draft.canAddLink)
        }
    }
}
