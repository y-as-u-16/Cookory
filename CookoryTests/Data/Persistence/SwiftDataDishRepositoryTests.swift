import Foundation
import Testing
@testable import Cookory

struct SwiftDataDishRepositoryTests {
    private func makeRepository() throws -> SwiftDataDishRepository {
        SwiftDataDishRepository(store: try SwiftDataStore.makeInMemory())
    }

    private func dishName(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    @Test func 保存した料理をIDで取得できる() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("唐揚げ"))

        try await repository.save(dish)

        #expect(try await repository.find(id: dish.id)?.name.value == "唐揚げ")
    }

    @Test func 料理名で取得できる() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("肉じゃが"))
        try await repository.save(dish)

        #expect(try await repository.find(name: try dishName("肉じゃが"))?.id == dish.id)
    }

    @Test func 未登録の料理名ではnilを返す() async throws {
        let repository = try makeRepository()

        #expect(try await repository.find(name: try dishName("未登録")) == nil)
    }

    /// APP_DESIGN.md #11 —「唐揚げ」を何度作っても Dish は 1 件のまま。
    @Test func 同じ料理を二度保存しても重複しない() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("唐揚げ"))

        try await repository.save(dish)
        try await repository.save(dish.favoriteToggled())

        let found = try #require(try await repository.find(name: try dishName("唐揚げ")))
        #expect(found.id == dish.id)
        #expect(found.isFavorite)
    }

    @Test func Domain往復で値が変わらない() async throws {
        let repository = try makeRepository()
        let original = Dish(
            name: try dishName("カレー"),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ).favoriteToggled(at: Date(timeIntervalSince1970: 1_700_003_600))

        try await repository.save(original)

        #expect(try await repository.find(id: original.id) == original)
    }

    @Test func 削除が反映される() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("味噌汁"))
        try await repository.save(dish)

        try await repository.delete(id: dish.id)

        #expect(try await repository.find(id: dish.id) == nil)
    }

    /// 料理を消したら調理履歴も消える。孤児の DishLog が残ると
    /// 「作った回数」の集計が実在しない料理を数え始める。
    @Test func 料理を削除すると調理履歴も消える() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("餃子"))
        try await repository.save(dish)
        let log = DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date())
        try await repository.save(log)

        try await repository.delete(id: dish.id)

        #expect(try await repository.fetchLogs(dishID: dish.id).isEmpty)
    }

    /// 他の料理の履歴まで巻き込んで消していないか。
    @Test func 料理の削除は他の料理の履歴に影響しない() async throws {
        let repository = try makeRepository()
        let target = Dish(name: try dishName("餃子"))
        let other = Dish(name: try dishName("春巻き"))
        try await repository.save(target)
        try await repository.save(other)
        try await repository.save(DishLog(dishID: target.id, mealRecordID: UUID(), cookedAt: Date()))
        try await repository.save(DishLog(dishID: other.id, mealRecordID: UUID(), cookedAt: Date()))

        try await repository.delete(id: target.id)

        #expect(try await repository.fetchLogs(dishID: other.id).count == 1)
    }

    @Test func 調理履歴からDishを辿れる() async throws {
        let repository = try makeRepository()
        let dish = Dish(name: try dishName("親子丼"))
        try await repository.save(dish)
        try await repository.save(DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()))

        let log = try #require(try await repository.fetchLogs(dishID: dish.id).first)

        #expect(try await repository.find(id: log.dishID)?.name.value == "親子丼")
    }

    @Test func 調理履歴を食事記録から取得できる() async throws {
        let repository = try makeRepository()
        let mealRecordID = UUID()
        try await repository.save(DishLog(dishID: UUID(), mealRecordID: mealRecordID, cookedAt: Date()))
        try await repository.save(DishLog(dishID: UUID(), mealRecordID: UUID(), cookedAt: Date()))

        #expect(try await repository.fetchLogs(mealRecordID: mealRecordID).count == 1)
    }

    @Test func 調理履歴は新しい順に並ぶ() async throws {
        let repository = try makeRepository()
        let dishID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let old = DishLog(dishID: dishID, mealRecordID: UUID(), cookedAt: base)
        let recent = DishLog(
            dishID: dishID, mealRecordID: UUID(), cookedAt: base.addingTimeInterval(3600)
        )
        try await repository.save(old)
        try await repository.save(recent)

        let logs = try await repository.fetchLogs(dishID: dishID)

        #expect(logs.map(\.id) == [recent.id, old.id])
    }

    @Test func 調理履歴のDomain往復で値が変わらない() async throws {
        let repository = try makeRepository()
        let original = DishLog(
            dishID: UUID(),
            mealRecordID: UUID(),
            rating: DishRating(4),
            note: "次は弱火で",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await repository.save(original)
        let restored = try #require(try await repository.fetchLogs(dishID: original.dishID).first)

        #expect(restored == original)
    }

    @Test func 評価とメモがnilでも往復できる() async throws {
        let repository = try makeRepository()
        let original = DishLog(
            dishID: UUID(),
            mealRecordID: UUID(),
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await repository.save(original)
        let restored = try #require(try await repository.fetchLogs(dishID: original.dishID).first)

        #expect(restored == original)
        #expect(restored.rating == nil)
        #expect(restored.note == nil)
    }

    @Test func 調理履歴の更新は重複を作らない() async throws {
        let repository = try makeRepository()
        let log = DishLog(dishID: UUID(), mealRecordID: UUID(), cookedAt: Date())
        try await repository.save(log)

        try await repository.save(log.rated(DishRating(5)))

        let logs = try await repository.fetchLogs(dishID: log.dishID)
        #expect(logs.count == 1)
        #expect(logs.first?.rating == DishRating(5))
    }

    @Test func 調理履歴を個別に削除できる() async throws {
        let repository = try makeRepository()
        let log = DishLog(dishID: UUID(), mealRecordID: UUID(), cookedAt: Date())
        try await repository.save(log)

        try await repository.deleteLog(id: log.id)

        #expect(try await repository.fetchLogs(dishID: log.dishID).isEmpty)
    }

    @Test func 存在しない調理履歴の削除は失敗しない() async throws {
        let repository = try makeRepository()

        try await repository.deleteLog(id: UUID())
    }
}
