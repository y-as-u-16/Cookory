import Foundation
import Testing
@testable import Cookory

struct DeleteMealRecordUseCaseTests {
    private func make() -> (
        DeleteMealRecordUseCase, InMemoryMealRecordRepository,
        InMemoryDishRepository, InMemoryImageStorage
    ) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let storage = InMemoryImageStorage()
        let useCase = DeleteMealRecordUseCase(
            mealRepository: meals, dishRepository: dishes, imageStorage: storage
        )
        return (useCase, meals, dishes, storage)
    }

    @Test func 記録を削除できる() async throws {
        let (useCase, meals, _, _) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        try await useCase.execute(id: meal.id)

        #expect(try await meals.find(id: meal.id) == nil)
    }

    @Test func 紐づくDishLogも消える() async throws {
        let (useCase, meals, dishes, _) = make()
        let dishID = UUID()
        var meal = MealRecord(occurredAt: Date())
        let log = DishLog(dishID: dishID, mealRecordID: meal.id, cookedAt: Date())
        meal = meal.addingDishLog(log.id)
        try await meals.save(meal)
        try await dishes.save(log)

        try await useCase.execute(id: meal.id)

        #expect(await dishes.logCount == 0)
    }

    /// 履歴が 0 件になっても「唐揚げを作れる」事実は残る。
    /// ここで Dish まで消すと Cookbook から料理が消え、利用者の意図と異なる。
    @Test func DishLogが0件になってもDishは残る() async throws {
        let (useCase, meals, dishes, _) = make()
        let dish = Dish(name: try #require(DishName("唐揚げ")))
        try await dishes.save(dish)
        var meal = MealRecord(occurredAt: Date())
        let log = DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: Date())
        meal = meal.addingDishLog(log.id)
        try await meals.save(meal)
        try await dishes.save(log)

        try await useCase.execute(id: meal.id)

        #expect(await dishes.dishCount == 1)
        #expect(try await dishes.find(id: dish.id) != nil)
    }

    @Test func 写真も削除される() async throws {
        let (useCase, meals, _, storage) = make()
        let asset = try await storage.save(Data("photo".utf8))
        let meal = MealRecord(occurredAt: Date()).addingPhoto(asset.id)
        try await meals.save(meal)

        try await useCase.execute(id: meal.id)

        #expect(await storage.savedCount == 0)
    }

    @Test func 存在しないIDの削除は失敗しない() async throws {
        let (useCase, _, _, _) = make()

        try await useCase.execute(id: UUID())
    }

    /// 他の記録の写真や履歴を巻き込んでいないか。
    @Test func 他の記録には影響しない() async throws {
        let (useCase, meals, dishes, storage) = make()
        let keptAsset = try await storage.save(Data("keep".utf8))
        let kept = MealRecord(occurredAt: Date()).addingPhoto(keptAsset.id)
        let keptLog = DishLog(dishID: UUID(), mealRecordID: kept.id, cookedAt: Date())
        try await meals.save(kept.addingDishLog(keptLog.id))
        try await dishes.save(keptLog)

        let target = MealRecord(occurredAt: Date())
        try await meals.save(target)

        try await useCase.execute(id: target.id)

        #expect(try await meals.find(id: kept.id) != nil)
        #expect(await dishes.logCount == 1)
        #expect(await storage.savedCount == 1)
    }
}
