import Foundation
import Testing
@testable import Cookory

/// 壊れたデータを読んだときの振る舞い。Repository 経由では作れないので
/// Model を直接組み立てて検証する。
struct MapperTests {
    @Test func 不正な料理名はinvalidInputになる() throws {
        let model = DishModel(
            id: UUID(), name: "   ", isFavorite: false, createdAt: Date(), updatedAt: Date()
        )

        #expect(throws: DomainError.invalidInput(reason: "保存された料理名が不正です")) {
            try model.toDomain()
        }
    }

    /// 評価は任意項目。壊れていても記録全体を読めるほうが損失が小さい。
    @Test func 範囲外の評価はnilに落ちる() {
        let model = DishLogModel(
            id: UUID(), dishID: UUID(), mealRecordID: UUID(),
            rating: 99, note: nil, cookedAt: Date()
        )

        #expect(model.toDomain().rating == nil)
    }

    @Test func 未知のmealTypeはnilに落ちる() {
        let model = MealRecordModel(
            id: UUID(), occurredAt: Date(), mealTypeRawValue: "brunch", note: nil,
            photoIDs: [], dishLogIDs: [], createdAt: Date(), updatedAt: Date()
        )

        #expect(model.toDomain().mealType == nil)
    }

    @Test func PhotoAssetが往復できる() {
        let original = PhotoAsset(filename: "original.jpg", width: 1024, height: 768)

        #expect(PhotoAssetModel(from: original).toDomain() == original)
    }

    @Test func 壊れたリンクが1件あっても残りを読める() {
        let json = """
        [{"id":"\(UUID().uuidString)","url":"https://example.com/a","title":"A"},\
        {"id":"not-a-uuid","url":"https://example.com/b","title":"B"},\
        {"id":"\(UUID().uuidString)","url":"https://example.com/c","title":"C"}]
        """
        let model = makeRecipeModel(linksJSON: json)

        let links = model.toDomain().links

        #expect(links.count == 2)
        #expect(links.map(\.title) == ["A", "C"])
    }

    @Test func 壊れた写真IDが1件あっても残りを読める() {
        let kept = UUID()
        let json = """
        ["\(kept.uuidString)","not-a-uuid"]
        """
        let model = makeRecipeModel(photoIDsJSON: json)

        #expect(model.toDomain().photoIDs == [kept])
    }

    /// 配列の外形が壊れていれば救えない。要素単位の救済と区別する。
    @Test func JSONとして壊れたリンクは空になる() {
        let model = makeRecipeModel(linksJSON: "{壊れている")

        #expect(model.toDomain().links.isEmpty)
    }

    private func makeRecipeModel(
        linksJSON: String? = nil,
        photoIDsJSON: String? = nil
    ) -> RecipeModel {
        RecipeModel(
            id: UUID(), dishID: UUID(), ingredients: nil, steps: nil,
            linksJSON: linksJSON, photoIDsJSON: photoIDsJSON,
            createdAt: Date(), updatedAt: Date()
        )
    }
}
