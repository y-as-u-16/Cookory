import Foundation
import Testing
@testable import Cookory

struct SwiftDataSearchQueryTests {
    private func make() throws -> (SwiftDataSearchQuery, SwiftDataDishRepository, SwiftDataMealRecordRepository) {
        let store = try SwiftDataStore.makeInMemory()
        return (
            SwiftDataSearchQuery(store: store),
            SwiftDataDishRepository(store: store),
            SwiftDataMealRecordRepository(store: store)
        )
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    @Test func 料理名で検索できる() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("唐揚げ")))
        try await dishes.save(Dish(name: try name("肉じゃが")))

        let results = try await query.search(keyword: "唐揚げ", limit: 50)

        #expect(results.dishes.count == 1)
        #expect(results.dishes.first?.dish.name.value == "唐揚げ")
    }

    @Test func 部分一致で検索できる() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("鶏の唐揚げ")))

        #expect(try await query.search(keyword: "唐揚", limit: 50).dishes.count == 1)
    }

    @Test func メモの内容で検索できる() async throws {
        let (query, _, meals) = try make()
        try await meals.save(MealRecord(occurredAt: Date(), note: "片栗粉多め"))
        try await meals.save(MealRecord(occurredAt: Date(), note: "薄味"))

        let results = try await query.search(keyword: "片栗粉", limit: 50)

        #expect(results.meals.count == 1)
    }

    @Test func 該当なしなら空になる() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("唐揚げ")))

        #expect(try await query.search(keyword: "存在しない料理", limit: 50).isEmpty)
    }

    /// 空白だけの入力で全件が返ると、検索の意味がなくなる。
    @Test func 空文字では何も返さない() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("唐揚げ")))

        #expect(try await query.search(keyword: "", limit: 50).isEmpty)
        #expect(try await query.search(keyword: "   ", limit: 50).isEmpty)
    }

    @Test func 調理回数が結果に入る() async throws {
        let (query, dishes, _) = try make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        for _ in 0..<3 {
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date())
            )
        }

        #expect(try await query.search(keyword: "唐揚げ", limit: 50).dishes.first?.cookCount == 3)
    }

    @Test func 作っていない料理も検索に出る() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("未調理")))

        let results = try await query.search(keyword: "未調理", limit: 50)

        #expect(results.dishes.count == 1)
        #expect(results.dishes.first?.cookCount == 0)
    }

    @Test func 件数に上限がある() async throws {
        let (query, dishes, _) = try make()
        for index in 0..<10 {
            try await dishes.save(Dish(name: try name("カレー\(index)")))
        }

        #expect(try await query.search(keyword: "カレー", limit: 3).dishes.count == 3)
    }

    @Test func limitが0以下なら空を返す() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("唐揚げ")))

        #expect(try await query.search(keyword: "唐揚げ", limit: 0).isEmpty)
    }

    @Test func 料理とメモの両方が返る() async throws {
        let (query, dishes, meals) = try make()
        try await dishes.save(Dish(name: try name("カレー")))
        try await meals.save(MealRecord(occurredAt: Date(), note: "カレーの隠し味"))

        let results = try await query.search(keyword: "カレー", limit: 50)

        #expect(results.dishes.count == 1)
        #expect(results.meals.count == 1)
    }

    @Test func 前後の空白は無視される() async throws {
        let (query, dishes, _) = try make()
        try await dishes.save(Dish(name: try name("唐揚げ")))

        #expect(try await query.search(keyword: "  唐揚げ  ", limit: 50).dishes.count == 1)
    }
}
