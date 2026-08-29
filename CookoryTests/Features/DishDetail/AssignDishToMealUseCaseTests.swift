import Foundation
import Testing
@testable import Cookory

struct AssignDishToMealUseCaseTests {
    private func make() -> (AssignDishToMealUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (AssignDishToMealUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes)
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    @Test func 新しい料理名でDishが1件作られる() async throws {
        let (useCase, meals, dishes) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        try await useCase.execute(mealRecordID: meal.id, dishName: try name("唐揚げ"))

        #expect(await dishes.dishCount == 1)
        #expect(await dishes.logCount == 1)
    }

    /// これを間違えると Cookbook に「唐揚げ」が何件も並ぶ。
    @Test func 同じ料理名ならDishは増えずDishLogだけ増える() async throws {
        let (useCase, meals, dishes) = make()
        let first = MealRecord(occurredAt: Date())
        let second = MealRecord(occurredAt: Date())
        try await meals.save(first)
        try await meals.save(second)

        try await useCase.execute(mealRecordID: first.id, dishName: try name("唐揚げ"))
        try await useCase.execute(mealRecordID: second.id, dishName: try name("唐揚げ"))

        #expect(await dishes.dishCount == 1)
        #expect(await dishes.logCount == 2)
    }

    @Test func 違う料理名なら別のDishになる() async throws {
        let (useCase, meals, dishes) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        try await useCase.execute(mealRecordID: meal.id, dishName: try name("唐揚げ"))
        try await useCase.execute(mealRecordID: meal.id, dishName: try name("肉じゃが"))

        #expect(await dishes.dishCount == 2)
    }

    /// MVP は完全一致。表記ゆれの正規化は Phase 1.2 で検討する。
    @Test func 表記ゆれは別のDishになる() async throws {
        let (useCase, meals, dishes) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        try await useCase.execute(mealRecordID: meal.id, dishName: try name("唐揚げ"))
        try await useCase.execute(mealRecordID: meal.id, dishName: try name("からあげ"))

        #expect(await dishes.dishCount == 2)
    }

    @Test func 評価とメモがDishLogに保存される() async throws {
        let (useCase, meals, _) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        let log = try await useCase.execute(
            mealRecordID: meal.id,
            dishName: try name("カレー"),
            rating: DishRating(5),
            note: "隠し味にチョコ"
        )

        #expect(log.rating == DishRating(5))
        #expect(log.note == "隠し味にチョコ")
    }

    @Test func 食事記録にDishLogのIDが追加される() async throws {
        let (useCase, meals, _) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        let log = try await useCase.execute(mealRecordID: meal.id, dishName: try name("味噌汁"))

        let updated = try await meals.find(id: meal.id)
        #expect(updated?.dishLogIDs == [log.id])
    }

    /// 調理日は記録の日時に合わせる。後から料理名を足しても履歴の日付がずれない。
    @Test func 調理日は食事記録の日時になる() async throws {
        let (useCase, meals, _) = make()
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let meal = MealRecord(occurredAt: occurredAt)
        try await meals.save(meal)

        let log = try await useCase.execute(mealRecordID: meal.id, dishName: try name("親子丼"))

        #expect(log.cookedAt == occurredAt)
    }

    @Test func 存在しない記録に紐づけると失敗する() async throws {
        let (useCase, _, dishes) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.execute(mealRecordID: missingID, dishName: try self.name("唐揚げ"))
        }

        #expect(await dishes.dishCount == 0)
    }
}
