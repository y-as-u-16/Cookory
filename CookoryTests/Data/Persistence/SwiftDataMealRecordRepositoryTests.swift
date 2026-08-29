import Foundation
import Testing
@testable import Cookory

struct SwiftDataMealRecordRepositoryTests {
    private func makeRepository() throws -> SwiftDataMealRecordRepository {
        SwiftDataMealRecordRepository(store: try SwiftDataStore.makeInMemory())
    }

    @Test func 保存した記録をIDで取得できる() async throws {
        let repository = try makeRepository()
        let meal = MealRecord(occurredAt: Date(), mealType: .dinner, note: "おいしかった")

        try await repository.save(meal)
        let found = try await repository.find(id: meal.id)

        #expect(found?.id == meal.id)
        #expect(found?.mealType == .dinner)
        #expect(found?.note == "おいしかった")
    }

    @Test func 存在しないIDではnilを返す() async throws {
        let repository = try makeRepository()

        #expect(try await repository.find(id: UUID()) == nil)
    }

    @Test func 削除が反映される() async throws {
        let repository = try makeRepository()
        let meal = MealRecord(occurredAt: Date())
        try await repository.save(meal)

        try await repository.delete(id: meal.id)

        #expect(try await repository.find(id: meal.id) == nil)
    }

    /// 削除の再実行を安全にする、という protocol の約束を守れているか。
    @Test func 存在しないIDの削除は失敗しない() async throws {
        let repository = try makeRepository()

        try await repository.delete(id: UUID())
    }

    @Test func Domain往復で値が変わらない() async throws {
        let repository = try makeRepository()
        let photoID = UUID()
        let dishLogID = UUID()
        let original = MealRecord(occurredAt: Date(timeIntervalSince1970: 1_700_000_000))
            .addingPhoto(photoID)
            .addingDishLog(dishLogID)
            .edited(mealType: .lunch, note: "塩を控えめに")

        try await repository.save(original)
        let restored = try #require(try await repository.find(id: original.id))

        #expect(restored == original)
    }

    /// mealType と note は任意項目。nil のまま往復できないと記録が壊れる。
    @Test func 任意項目がnilでも往復できる() async throws {
        let repository = try makeRepository()
        let original = MealRecord(occurredAt: Date(timeIntervalSince1970: 1_700_000_000))

        try await repository.save(original)
        let restored = try #require(try await repository.find(id: original.id))

        #expect(restored == original)
        #expect(restored.mealType == nil)
        #expect(restored.note == nil)
    }

    @Test func 同じIDを二度保存しても重複しない() async throws {
        let repository = try makeRepository()
        let meal = MealRecord(occurredAt: Date(), note: "初回")

        try await repository.save(meal)
        try await repository.save(meal.edited(mealType: .breakfast, note: "修正後"))

        let all = try await repository.fetchRecent(limit: 100)
        #expect(all.count == 1)
        #expect(all.first?.note == "修正後")
    }

    @Test func 新しい順に取得する() async throws {
        let repository = try makeRepository()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let old = MealRecord(occurredAt: base)
        let recent = MealRecord(occurredAt: base.addingTimeInterval(3600))
        try await repository.save(old)
        try await repository.save(recent)

        let all = try await repository.fetchRecent(limit: 10)

        #expect(all.map(\.id) == [recent.id, old.id])
    }

    @Test func limitを超える件数は返さない() async throws {
        let repository = try makeRepository()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in 0..<5 {
            try await repository.save(
                MealRecord(occurredAt: base.addingTimeInterval(Double(offset) * 3600))
            )
        }

        #expect(try await repository.fetchRecent(limit: 3).count == 3)
    }

    @Test func limitが0以下なら空を返す() async throws {
        let repository = try makeRepository()
        try await repository.save(MealRecord(occurredAt: Date()))

        #expect(try await repository.fetchRecent(limit: 0).isEmpty)
    }
}
