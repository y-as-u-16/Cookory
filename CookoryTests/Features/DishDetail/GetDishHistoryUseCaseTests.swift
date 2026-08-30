import Foundation
import Testing
@testable import Cookory

struct GetDishHistoryUseCaseTests {
    private func make() -> (GetDishHistoryUseCase, InMemoryDishRepository, InMemoryMealRecordRepository) {
        let dishes = InMemoryDishRepository()
        let meals = InMemoryMealRecordRepository()
        return (
            GetDishHistoryUseCase(dishRepository: dishes, mealRepository: meals), dishes, meals
        )
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    private var base: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func daysAgo(_ days: Int) -> Date {
        base.addingTimeInterval(-Double(days) * 86_400)
    }

    @Test func 調理回数と最終調理日が正しい() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        for days in [1, 20, 60] {
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(days))
            )
        }

        let history = try await useCase.execute(dishID: dish.id)

        #expect(history.cookCount == 3)
        #expect(history.lastCookedAt == daysAgo(1))
    }

    @Test func 履歴が新しい順に並ぶ() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("カレー"))
        try await dishes.save(dish)
        for days in [30, 1, 10] {
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(days))
            )
        }

        let history = try await useCase.execute(dishID: dish.id)

        #expect(history.entries.map(\.log.cookedAt) == [daysAgo(1), daysAgo(10), daysAgo(30)])
    }

    @Test func 各履歴の評価とメモが取れる() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(DishLog(
            dishID: dish.id, mealRecordID: UUID(),
            rating: DishRating(5), note: "片栗粉多め", cookedAt: daysAgo(1)
        ))

        let entry = try #require(try await useCase.execute(dishID: dish.id).entries.first)

        #expect(entry.log.rating == DishRating(5))
        #expect(entry.log.note == "片栗粉多め")
    }

    @Test func 履歴に写真が紐づく() async throws {
        let (useCase, dishes, meals) = make()
        let photoID = UUID()
        let meal = MealRecord(occurredAt: daysAgo(1)).addingPhoto(photoID)
        try await meals.save(meal)
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: daysAgo(1))
        )

        let history = try await useCase.execute(dishID: dish.id)

        #expect(history.entries.first?.photoID == photoID)
        #expect(history.latestPhotoID == photoID)
    }

    /// 最新の履歴に写真が無くても、次に古い履歴の写真を出す。
    @Test func 最新に写真が無ければ次を探す() async throws {
        let (useCase, dishes, meals) = make()
        let photoID = UUID()
        let withPhoto = MealRecord(occurredAt: daysAgo(10)).addingPhoto(photoID)
        let withoutPhoto = MealRecord(occurredAt: daysAgo(1))
        try await meals.save(withPhoto)
        try await meals.save(withoutPhoto)
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: withoutPhoto.id, cookedAt: daysAgo(1))
        )
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: withPhoto.id, cookedAt: daysAgo(10))
        )

        #expect(try await useCase.execute(dishID: dish.id).latestPhotoID == photoID)
    }

    /// 履歴が 1 件でも破綻しない。
    @Test func 履歴が1件でも成立する() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("味噌汁"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(1))
        )

        let history = try await useCase.execute(dishID: dish.id)

        #expect(history.cookCount == 1)
        #expect(history.lastCookedAt == daysAgo(1))
    }

    @Test func 履歴が0件でも成立する() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("未調理"))
        try await dishes.save(dish)

        let history = try await useCase.execute(dishID: dish.id)

        #expect(history.cookCount == 0)
        #expect(history.lastCookedAt == nil)
        #expect(history.latestPhotoID == nil)
    }

    @Test func 存在しない料理は失敗する() async throws {
        let (useCase, _, _) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.execute(dishID: missingID)
        }
    }

    @Test func 他の料理の履歴は混ざらない() async throws {
        let (useCase, dishes, _) = make()
        let target = Dish(name: try name("唐揚げ"))
        let other = Dish(name: try name("カレー"))
        try await dishes.save(target)
        try await dishes.save(other)
        try await dishes.save(
            DishLog(dishID: target.id, mealRecordID: UUID(), cookedAt: daysAgo(1))
        )
        try await dishes.save(
            DishLog(dishID: other.id, mealRecordID: UUID(), cookedAt: daysAgo(1))
        )

        #expect(try await useCase.execute(dishID: target.id).cookCount == 1)
    }

    @Test func お気に入りを切り替えられる() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)

        let favorited = try await useCase.toggleFavorite(dishID: dish.id)
        #expect(favorited.isFavorite)

        let unfavorited = try await useCase.toggleFavorite(dishID: dish.id)
        #expect(!unfavorited.isFavorite)
    }

    @Test func お気に入りが保存される() async throws {
        let (useCase, dishes, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)

        try await useCase.toggleFavorite(dishID: dish.id)

        #expect(try await dishes.find(id: dish.id)?.isFavorite == true)
    }
}
