import Foundation
import Testing
@testable import Cookory

struct EditRecipeUseCaseTests {
    private func make() -> (EditRecipeUseCase, InMemoryDishRepository) {
        let dishes = InMemoryDishRepository()
        return (EditRecipeUseCase(dishRepository: dishes, imageStorage: InMemoryImageStorage()), dishes)
    }

    /// 未作成でも空のレシピを返す。画面側で分岐させないため。
    @Test func 未作成なら空のレシピを返す() async throws {
        let (useCase, _) = make()
        let dishID = UUID()

        let recipe = try await useCase.find(dishID: dishID)

        #expect(recipe.isEmpty)
        #expect(recipe.dishID == dishID)
    }

    @Test func 材料と手順を保存できる() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()

        try await useCase.updateContent(
            dishID: dishID, ingredients: "鶏もも肉 300g", steps: "1. 下味をつける"
        )

        let saved = try await dishes.findRecipe(dishID: dishID)
        #expect(saved?.ingredients == "鶏もも肉 300g")
        #expect(saved?.steps == "1. 下味をつける")
    }

    @Test func 書き換えても重複しない() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()
        try await useCase.updateContent(dishID: dishID, ingredients: "初版", steps: nil)

        try await useCase.updateContent(dishID: dishID, ingredients: "改訂版", steps: nil)

        #expect(try await dishes.findRecipe(dishID: dishID)?.ingredients == "改訂版")
    }

    /// 空のレシピを残すと「レシピあり」と「中身が空」の区別がつかない。
    @Test func すべて空にすると削除される() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()
        try await useCase.updateContent(dishID: dishID, ingredients: "材料", steps: "手順")

        try await useCase.updateContent(dishID: dishID, ingredients: "", steps: "  ")

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
    }

    @Test func リンクを追加できる() async throws {
        let (useCase, _) = make()
        let dishID = UUID()

        let recipe = try await useCase.addLink(
            dishID: dishID, rawURL: "https://example.com/recipe", title: "参考"
        )

        #expect(recipe.links.count == 1)
        #expect(recipe.links.first?.displayName == "参考")
    }

    @Test func 不正なリンクは追加できない() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()

        await #expect(throws: DomainError.invalidInput(reason: "リンクとして読み取れませんでした")) {
            try await useCase.addLink(dishID: dishID, rawURL: "javascript:alert(1)", title: nil)
        }

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
    }

    /// 同じ URL を二度貼っても増やさない。
    @Test func 同じURLは重複しない() async throws {
        let (useCase, _) = make()
        let dishID = UUID()
        try await useCase.addLink(dishID: dishID, rawURL: "https://example.com", title: nil)

        let recipe = try await useCase.addLink(
            dishID: dishID, rawURL: "https://example.com", title: "別名"
        )

        #expect(recipe.links.count == 1)
    }

    @Test func リンクを削除できる() async throws {
        let (useCase, _) = make()
        let dishID = UUID()
        let added = try await useCase.addLink(
            dishID: dishID, rawURL: "https://example.com", title: nil
        )
        let linkID = try #require(added.links.first?.id)

        let recipe = try await useCase.removeLink(dishID: dishID, linkID: linkID)

        #expect(recipe.links.isEmpty)
    }

    @Test func リンクだけでもレシピは残る() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()

        try await useCase.addLink(dishID: dishID, rawURL: "https://example.com", title: nil)

        #expect(try await dishes.findRecipe(dishID: dishID) != nil)
    }

    /// 最後のリンクを消したら中身が空になるため、レシピごと消える。
    @Test func 最後のリンクを消すとレシピも消える() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()
        let added = try await useCase.addLink(
            dishID: dishID, rawURL: "https://example.com", title: nil
        )
        let linkID = try #require(added.links.first?.id)

        try await useCase.removeLink(dishID: dishID, linkID: linkID)

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
    }

    @Test func 材料が残っていればリンクを消してもレシピは残る() async throws {
        let (useCase, dishes) = make()
        let dishID = UUID()
        try await useCase.updateContent(dishID: dishID, ingredients: "材料", steps: nil)
        let added = try await useCase.addLink(
            dishID: dishID, rawURL: "https://example.com", title: nil
        )
        let linkID = try #require(added.links.first?.id)

        try await useCase.removeLink(dishID: dishID, linkID: linkID)

        #expect(try await dishes.findRecipe(dishID: dishID)?.ingredients == "材料")
    }
}
