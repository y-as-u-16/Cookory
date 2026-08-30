import Foundation
import Observation

@MainActor
@Observable
final class RecipeEditorViewModel {
    private(set) var recipe: Recipe?
    private(set) var errorMessage: LocalizedStringResource?
    private(set) var isLoaded = false

    var ingredientsDraft: String = ""
    var stepsDraft: String = ""
    var linkURLDraft: String = ""
    var linkTitleDraft: String = ""

    private let dishID: UUID
    private let editRecipe: EditRecipeUseCase

    init(dishID: UUID, editRecipe: EditRecipeUseCase) {
        self.dishID = dishID
        self.editRecipe = editRecipe
    }

    var canAddLink: Bool {
        RecipeLink(rawURL: linkURLDraft) != nil
    }

    var links: [RecipeLink] { recipe?.links ?? [] }

    func load() async {
        do {
            let recipe = try await editRecipe.find(dishID: dishID)
            self.recipe = recipe
            // 書きかけを消さないよう初回だけ反映する。
            if !isLoaded {
                ingredientsDraft = recipe.ingredients ?? ""
                stepsDraft = recipe.steps ?? ""
                isLoaded = true
            }
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorLoad
        }
    }

    func save() async {
        do {
            recipe = try await editRecipe.updateContent(
                dishID: dishID, ingredients: ingredientsDraft, steps: stepsDraft
            )
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorSave
        }
    }

    func addLink() async {
        do {
            recipe = try await editRecipe.addLink(
                dishID: dishID, rawURL: linkURLDraft, title: linkTitleDraft
            )
            linkURLDraft = ""
            linkTitleDraft = ""
            errorMessage = nil
        } catch DomainError.invalidInput {
            // Domain の文言は利用者向けではない。表示は Presentation で決める。
            errorMessage = L10n.errorInvalidLink
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    func removeLink(id: UUID) async {
        do {
            recipe = try await editRecipe.removeLink(dishID: dishID, linkID: id)
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }
}
