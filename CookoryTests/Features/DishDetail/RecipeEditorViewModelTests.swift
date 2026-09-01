import Foundation
import Testing
@testable import Cookory

@MainActor
struct RecipeEditorViewModelTests {
    private func make(
        dishID: UUID, dishes: InMemoryDishRepository = InMemoryDishRepository()
    ) -> RecipeEditorViewModel {
        RecipeEditorViewModel(dishID: dishID, editRecipe: EditRecipeUseCase(dishRepository: dishes))
    }

    @Test func 保存済みのレシピを読み込める() async throws {
        let dishes = InMemoryDishRepository()
        let dishID = UUID()
        try await dishes.save(Recipe(dishID: dishID, ingredients: "鶏もも肉", steps: "1. 揚げる"))
        let viewModel = make(dishID: dishID, dishes: dishes)

        await viewModel.load()

        #expect(viewModel.draft.ingredients == "鶏もも肉")
        #expect(viewModel.draft.steps == "1. 揚げる")
    }

    @Test func レシピが無くても空で開ける() async throws {
        let viewModel = make(dishID: UUID())

        await viewModel.load()

        #expect(viewModel.draft.ingredients.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func 材料と手順を保存できる() async throws {
        let dishes = InMemoryDishRepository()
        let dishID = UUID()
        let viewModel = make(dishID: dishID, dishes: dishes)
        await viewModel.load()

        viewModel.draft.ingredients = "じゃがいも 3個"
        viewModel.draft.steps = "1. 煮る"
        await viewModel.save()

        let saved = try #require(try await dishes.findRecipe(dishID: dishID))
        #expect(saved.ingredients == "じゃがいも 3個")
        #expect(saved.steps == "1. 煮る")
    }

    @Test func リンクを追加できる() async throws {
        let dishID = UUID()
        let viewModel = make(dishID: dishID)
        await viewModel.load()

        viewModel.draft.linkURL = "https://example.com/recipe"
        viewModel.draft.linkTitle = "参考"
        await viewModel.addLink()

        #expect(viewModel.links.count == 1)
        #expect(viewModel.draft.linkURL.isEmpty)
    }

    @Test func 不正なリンクは弾かれる() async throws {
        let viewModel = make(dishID: UUID())
        await viewModel.load()

        viewModel.draft.linkURL = "javascript:alert(1)"

        #expect(!viewModel.canAddLink)
        await viewModel.addLink()
        #expect(viewModel.links.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func リンクを削除できる() async throws {
        let dishID = UUID()
        let viewModel = make(dishID: dishID)
        await viewModel.load()
        viewModel.draft.linkURL = "https://example.com/recipe"
        await viewModel.addLink()
        let linkID = try #require(viewModel.links.first?.id)

        await viewModel.removeLink(id: linkID)

        #expect(viewModel.links.isEmpty)
    }

    /// 記録画面と同じ書きかけの部品を使う。片方だけ直す修正を防ぐため。
    @Test func 書きかけは再読み込みで消えない() async throws {
        let dishes = InMemoryDishRepository()
        let dishID = UUID()
        try await dishes.save(Recipe(dishID: dishID, ingredients: "元の材料"))
        let viewModel = make(dishID: dishID, dishes: dishes)
        await viewModel.load()

        viewModel.draft.ingredients = "書きかけ"
        await viewModel.load()

        #expect(viewModel.draft.ingredients == "書きかけ")
    }

    @Test func 未編集の欄は他の画面での保存に追従する() async throws {
        let dishes = InMemoryDishRepository()
        let dishID = UUID()
        try await dishes.save(Recipe(dishID: dishID, ingredients: "元の材料"))
        let viewModel = make(dishID: dishID, dishes: dishes)
        await viewModel.load()

        // 記録画面など、別の入口から書き換えられた状態。
        try await dishes.save(Recipe(dishID: dishID, ingredients: "別画面で書いた材料"))
        await viewModel.load()

        #expect(viewModel.draft.ingredients == "別画面で書いた材料")
    }
}
