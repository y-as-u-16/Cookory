import Foundation
import Testing
@testable import Cookory

/// 記録から料理を外す操作を確かめる。
struct RemoveDishFromMealUseCaseTests {
    private func make() -> (RemoveDishFromMealUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (
            RemoveDishFromMealUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes
        )
    }

    private func seed(
        meals: InMemoryMealRecordRepository, dishes: InMemoryDishRepository, name: String
    ) async throws -> (MealRecord, Dish, DishLog) {
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let dish = Dish(name: try #require(DishName(name)))
        try await dishes.save(dish)
        let log = DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: Date())
        try await dishes.save(log)
        try await meals.save(meal.addingDishLog(log.id))
        return (meal, dish, log)
    }

    @Test func 料理を外せる() async throws {
        let (useCase, meals, dishes) = make()
        let (meal, _, log) = try await seed(meals: meals, dishes: dishes, name: "唐揚げ")

        try await useCase.execute(mealRecordID: meal.id, dishLogID: log.id)

        #expect(try await dishes.fetchLogs(mealRecordID: meal.id).isEmpty)
        #expect(try await meals.find(id: meal.id)?.dishLogIDs.isEmpty == true)
    }

    /// Dish 自体は消さない。「唐揚げを作れる」という事実まで消えるのは
    /// 打ち間違いの訂正としては行き過ぎ。
    @Test func 料理そのものは残る() async throws {
        let (useCase, meals, dishes) = make()
        let (meal, dish, log) = try await seed(meals: meals, dishes: dishes, name: "唐揚げ")

        try await useCase.execute(mealRecordID: meal.id, dishLogID: log.id)

        #expect(try await dishes.find(id: dish.id) != nil)
    }

    @Test func 存在しない記録でも失敗しない() async throws {
        let (useCase, _, _) = make()

        try await useCase.execute(mealRecordID: UUID(), dishLogID: UUID())
    }

    @Test func 他の料理は残る() async throws {
        let (useCase, meals, dishes) = make()
        let (meal, _, target) = try await seed(meals: meals, dishes: dishes, name: "唐揚げ")
        let salad = Dish(name: try #require(DishName("サラダ")))
        try await dishes.save(salad)
        let other = DishLog(dishID: salad.id, mealRecordID: meal.id, cookedAt: Date())
        try await dishes.save(other)
        let updated = try #require(try await meals.find(id: meal.id))
        try await meals.save(updated.addingDishLog(other.id))

        try await useCase.execute(mealRecordID: meal.id, dishLogID: target.id)

        let remaining = try await dishes.fetchLogs(mealRecordID: meal.id)
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == other.id)
    }
}
