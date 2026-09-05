import Foundation
import Observation

/// 料理図鑑から開くレシピ編集画面の状態。
///
/// 書きかけとリンクの検証は ``DishRecipeDraft`` が持つ。記録画面と同じ部品を
/// 使うことで、片方だけ直したつもりの修正が起きないようにする。
@MainActor
@Observable
final class RecipeEditorViewModel {
    let draft = DishRecipeDraft()

    private(set) var errorMessage: LocalizedStringResource?

    private let dishID: UUID
    private let editRecipe: EditRecipeUseCase

    init(dishID: UUID, editRecipe: EditRecipeUseCase) {
        self.dishID = dishID
        self.editRecipe = editRecipe
    }

    var links: [RecipeLink] { draft.links }

    var canAddLink: Bool { draft.canAddLink }

    func load() async {
        do {
            draft.apply(try await editRecipe.find(dishID: dishID))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorLoad
        }
    }

    func save() async {
        do {
            draft.apply(try await editRecipe.updateContent(
                dishID: dishID, ingredients: draft.ingredients, steps: draft.steps
            ))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorSave
        }
    }

    func addLink() async {
        do {
            draft.apply(try await editRecipe.addLink(
                dishID: dishID, rawURL: draft.linkURL, title: draft.linkTitle
            ))
            draft.clearLinkInput()
            errorMessage = nil
        } catch DomainError.invalidInput {
            // Domain の文言は利用者向けではない。表示は Presentation で決める。
            errorMessage = L10n.errorInvalidLink
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    func addPhotos(_ images: [Data]) async {
        guard !images.isEmpty else { return }
        do {
            draft.apply(try await editRecipe.addPhotos(dishID: dishID, images: images))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorImageStorage
        }
    }

    func removePhoto(id: UUID) async {
        do {
            draft.apply(try await editRecipe.removePhoto(dishID: dishID, photoID: id))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    func removeLink(id: UUID) async {
        do {
            draft.apply(try await editRecipe.removeLink(dishID: dishID, linkID: id))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }
}
