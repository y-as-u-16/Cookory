import Foundation
import Testing
@testable import Cookory

/// レシピに貼ったスクリーンショットの扱いを確かめる。
struct RecipePhotoTests {
    private func make() -> (EditRecipeUseCase, InMemoryDishRepository, InMemoryImageStorage) {
        let dishes = InMemoryDishRepository()
        let storage = InMemoryImageStorage()
        return (EditRecipeUseCase(dishRepository: dishes, imageStorage: storage), dishes, storage)
    }

    private var image: Data { Data("screenshot".utf8) }

    @Test func スクショを貼れる() async throws {
        let (useCase, dishes, storage) = make()
        let dishID = UUID()

        let recipe = try await useCase.addPhotos(dishID: dishID, images: [image, image])

        #expect(recipe.photoIDs.count == 2)
        #expect(await storage.savedCount == 2)
        #expect(try await dishes.findRecipe(dishID: dishID)?.photoIDs.count == 2)
    }

    @Test func 貼った順が保たれる() async throws {
        let (useCase, _, storage) = make()
        let dishID = UUID()
        let images = (0..<3).map { Data("shot-\($0)".utf8) }

        let recipe = try await useCase.addPhotos(dishID: dishID, images: images)

        for (index, photoID) in recipe.photoIDs.enumerated() {
            #expect(try await storage.load(id: photoID) == images[index])
        }
    }

    @Test func スクショを1枚だけ外せる() async throws {
        let (useCase, _, storage) = make()
        let dishID = UUID()
        let recipe = try await useCase.addPhotos(dishID: dishID, images: [image, image])
        let target = try #require(recipe.photoIDs.first)

        let updated = try await useCase.removePhoto(dishID: dishID, photoID: target)

        #expect(updated.photoIDs.count == 1)
        #expect(!updated.photoIDs.contains(target))
        // 外した画像の実体も消す。参照されないファイルが残り続けるため。
        #expect(await !storage.contains(id: target))
    }

    /// スクショだけのレシピも成立する。材料や手順を書かずに貼るだけの使い方があるため。
    @Test func スクショだけでもレシピとして残る() async throws {
        let (useCase, dishes, _) = make()
        let dishID = UUID()

        try await useCase.addPhotos(dishID: dishID, images: [image])

        #expect(try await dishes.findRecipe(dishID: dishID) != nil)
    }

    /// 中身が空になったらレシピごと消える。貼った画像も道連れにする。
    @Test func レシピが空になると画像も消える() async throws {
        let (useCase, dishes, storage) = make()
        let dishID = UUID()
        let recipe = try await useCase.addPhotos(dishID: dishID, images: [image])
        let photoID = try #require(recipe.photoIDs.first)

        try await useCase.removePhoto(dishID: dishID, photoID: photoID)

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
        #expect(await storage.savedCount == 0)
    }

    @Test func 材料を消してもスクショがあればレシピは残る() async throws {
        let (useCase, dishes, _) = make()
        let dishID = UUID()
        try await useCase.updateContent(dishID: dishID, ingredients: "鶏もも肉", steps: nil)
        try await useCase.addPhotos(dishID: dishID, images: [image])

        try await useCase.updateContent(dishID: dishID, ingredients: nil, steps: nil)

        let saved = try #require(try await dishes.findRecipe(dishID: dishID))
        #expect(saved.ingredients == nil)
        #expect(saved.photoIDs.count == 1)
    }

    @Test func 保存に失敗したら画像を残さない() async throws {
        let (useCase, _, storage) = make()
        await storage.setError(.imageStorageFailed)

        await #expect(throws: DomainError.imageStorageFailed) {
            try await useCase.addPhotos(dishID: UUID(), images: [image])
        }

        #expect(await storage.savedCount == 0)
    }
}
