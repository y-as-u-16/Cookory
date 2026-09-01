import Foundation

/// 料理の作り方を編集する。
struct EditRecipeUseCase: Sendable {
    private let dishRepository: DishRepository
    private let imageStorage: ImageStorage

    init(dishRepository: DishRepository, imageStorage: ImageStorage) {
        self.dishRepository = dishRepository
        self.imageStorage = imageStorage
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

    /// スクリーンショットを貼る。
    ///
    /// - Throws: 画像の保存に失敗した場合は ``DomainError/imageStorageFailed``。
    @discardableResult
    func addPhotos(dishID: UUID, images: [Data], now: Date = Date()) async throws -> Recipe {
        guard !images.isEmpty else { return try await find(dishID: dishID) }

        var assets: [PhotoAsset] = []
        do {
            for image in images {
                assets.append(try await imageStorage.save(image))
            }
        } catch {
            // レシピに載らない以上、参照する術がないため片づける。
            await deletePhotos(assets.map(\.id))
            throw error
        }

        let recipe = try await find(dishID: dishID).addingPhotos(assets.map(\.id), at: now)
        do {
            try await persist(recipe, dishID: dishID)
        } catch {
            await deletePhotos(assets.map(\.id))
            throw error
        }
        return recipe
    }

    @discardableResult
    func removePhoto(dishID: UUID, photoID: UUID, now: Date = Date()) async throws -> Recipe {
        let recipe = try await find(dishID: dishID).removingPhoto(id: photoID, at: now)
        try await persist(recipe, dishID: dishID)
        await deletePhotos([photoID])
        return recipe
    }

    /// レシピごと消えるときは、貼られていた画像も一緒に片づける。
    /// 残しても参照する術がなく、容量だけを食い続ける。
    private func persist(_ recipe: Recipe, dishID: UUID) async throws {
        if recipe.isEmpty {
            let orphaned = try await dishRepository.findRecipe(dishID: dishID)?.photoIDs ?? []
            try await dishRepository.deleteRecipe(dishID: dishID)
            await deletePhotos(orphaned)
        } else {
            try await dishRepository.save(recipe)
        }
    }

    /// 削除に失敗しても呼び出し側の処理は続ける。残るのは参照されない
    /// ファイルだけで、後から回収できる。
    private func deletePhotos(_ ids: [UUID]) async {
        for id in ids {
            try? await imageStorage.delete(id: id)
        }
    }
}
