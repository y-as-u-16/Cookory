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
}
