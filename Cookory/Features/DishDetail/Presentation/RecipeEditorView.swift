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

            // 記録画面で貼ったスクリーンショットをここでも見せる。レシピを
            // 画像で残す使い方だと、これが無いと読めない。
            Section(String(localized: L10n.recipePhotos)) {
                RecipePhotoStrip(
                    photoIDs: viewModel.draft.photoIDs,
                    onAdd: { images in Task { await viewModel.addPhotos(images) } },
                    onRemove: { id in Task { await viewModel.removePhoto(id: id) } }
                )
            }

            RecipeLinkFields(
                draft: viewModel.draft,
                onAdd: { Task { await viewModel.addLink() } },
                onRemove: { id in Task { await viewModel.removeLink(id: id) } }
            )

            if let message = viewModel.errorMessage {
                Section { InlineErrorView(message: message) }
            }
        }
        .navigationTitle(Text(L10n.recipeTitle))
        .navigationBarTitleDisplayMode(.inline)
        // Form の中間に置くと、リンクを足しに下へ行くたび保存が視界から消える。
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: L10n.recipeSave)) {
                    Task { await viewModel.save() }
                }
            }
        }
        .task { await viewModel.load() }
    }
}
