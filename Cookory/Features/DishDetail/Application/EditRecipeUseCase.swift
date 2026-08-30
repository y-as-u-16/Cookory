import Foundation

/// 料理の作り方を編集する。
struct EditRecipeUseCase: Sendable {
    private let dishRepository: DishRepository

    init(dishRepository: DishRepository) {
        self.dishRepository = dishRepository
    }

    /// 未作成なら空のレシピを返す。画面側で分岐させないため。
    func find(dishID: UUID) async throws -> Recipe {
        try await dishRepository.findRecipe(dishID: dishID) ?? Recipe(dishID: dishID)
    }

    /// 材料と手順を書き換える。
    ///
    /// すべて空になったらレシピごと削除する。空のレシピを残すと
    /// 「レシピあり」と「中身が空」の区別がつかなくなる。
    @discardableResult
    func updateContent(
        dishID: UUID, ingredients: String?, steps: String?, now: Date = Date()
    ) async throws -> Recipe {
        let recipe = try await find(dishID: dishID)
            .edited(ingredients: ingredients, steps: steps, at: now)
        try await persist(recipe, dishID: dishID)
        return recipe
    }

    @discardableResult
    func addLink(
        dishID: UUID, rawURL: String, title: String?, now: Date = Date()
    ) async throws -> Recipe {
        guard let link = RecipeLink(rawURL: rawURL, title: title) else {
            throw DomainError.invalidInput(reason: "リンクとして読み取れませんでした")
        }
        let recipe = try await find(dishID: dishID).addingLink(link, at: now)
        try await persist(recipe, dishID: dishID)
        return recipe
    }

    @discardableResult
    func removeLink(dishID: UUID, linkID: UUID, now: Date = Date()) async throws -> Recipe {
        let recipe = try await find(dishID: dishID).removingLink(id: linkID, at: now)
        try await persist(recipe, dishID: dishID)
        return recipe
    }

    private func persist(_ recipe: Recipe, dishID: UUID) async throws {
        if recipe.isEmpty {
            try await dishRepository.deleteRecipe(dishID: dishID)
        } else {
            try await dishRepository.save(recipe)
        }
    }
}
