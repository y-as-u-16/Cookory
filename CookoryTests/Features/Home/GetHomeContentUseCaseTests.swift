import Foundation
import Testing
@testable import Cookory

struct GetHomeContentUseCaseTests {
    private func make() -> (GetHomeContentUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (GetHomeContentUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes)
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    @Test func 記録が0件なら空になる() async throws {
        let (useCase, _, _) = make()

        let content = try await useCase.execute(now: now)

        #expect(content.isEmpty)
    }

    @Test func 最近の料理が新しい順に並ぶ() async throws {
        let (useCase, meals, _) = make()
        let old = MealRecord(occurredAt: daysAgo(3))
        let recent = MealRecord(occurredAt: daysAgo(1))
        try await meals.save(old)
        try await meals.save(recent)

        let content = try await useCase.execute(now: now)

        #expect(content.recentMeals.map(\.id) == [recent.id, old.id])
    }

    @Test func 最近の料理には上限がある() async throws {
        let (useCase, meals, _) = make()
        for day in 1...15 {
            try await meals.save(MealRecord(occurredAt: daysAgo(day)))
        }

        let content = try await useCase.execute(now: now)

        #expect(content.recentMeals.count == GetHomeContentUseCase.recentMealLimit)
    }

    @Test func 一定期間作っていない料理が出る() async throws {
        let (useCase, _, dishes) = make()
        let dish = Dish(name: try name("ハンバーグ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(83))
        )

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.count == 1)
        #expect(content.forgottenDishes.first?.daysSinceLastCooked == 83)
    }

    @Test func 最近作った料理は久しぶりに出ない() async throws {
        let (useCase, _, dishes) = make()
        let dish = Dish(name: try name("味噌汁"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(3))
        )

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.isEmpty)
    }

    /// 一度も作っていない料理は「久しぶり」ではない。
    @Test func 履歴の無い料理は久しぶりに出ない() async throws {
        let (useCase, _, dishes) = make()
        try await dishes.save(Dish(name: try name("未調理")))

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.isEmpty)
    }

    @Test func 久しぶりの料理は間隔が長い順に並ぶ() async throws {
        let (useCase, _, dishes) = make()
        for (dishName, days) in [("A", 40), ("B", 90), ("C", 60)] {
            let dish = Dish(name: try name(dishName))
            try await dishes.save(dish)
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(days))
            )
        }

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.map(\.dish.name.value) == ["B", "C", "A"])
    }

    @Test func 久しぶりの料理には上限がある() async throws {
        let (useCase, _, dishes) = make()
        for index in 0..<6 {
            let dish = Dish(name: try name("料理\(index)"))
            try await dishes.save(dish)
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(40 + index))
            )
        }

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.count == GetHomeContentUseCase.forgottenDishLimit)
    }

    /// 最終調理日で判定する。古い履歴があっても最近作っていれば出さない。
    @Test func 最終調理日で判定する() async throws {
        let (useCase, _, dishes) = make()
        let dish = Dish(name: try name("カレー"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(200))
        )
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: daysAgo(2))
        )

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.isEmpty)
    }
}

/// 記録が増えるほど出せるものが増える構成の検証。
struct HomeProgressiveContentTests {
    private func make() -> (GetHomeContentUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (GetHomeContentUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes)
    }

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    @Test func 記録が少ないうちは集計を出さない() async throws {
        let (useCase, meals, _) = make()
        try await meals.save(MealRecord(occurredAt: daysAgo(1)))

        let content = try await useCase.execute(now: now)

        #expect(!content.summary.isWorthShowing)
    }

    @Test func 記録が増えると集計が出る() async throws {
        let (useCase, meals, _) = make()
        for day in 1...4 {
            try await meals.save(MealRecord(occurredAt: daysAgo(day)))
        }

        let content = try await useCase.execute(now: now)

        #expect(content.summary.isWorthShowing)
        #expect(content.summary.totalRecords == 4)
        #expect(content.summary.daysCookedThisWeek == 4)
    }

    @Test func 料理の種類が数えられる() async throws {
        let (useCase, meals, dishes) = make()
        for day in 1...3 {
            try await meals.save(MealRecord(occurredAt: daysAgo(day)))
        }
        try await dishes.save(Dish(name: try name("唐揚げ")))
        try await dishes.save(Dish(name: try name("カレー")))

        #expect(try await useCase.execute(now: now).summary.distinctDishes == 2)
    }

    /// 久しぶりの料理に写真が付く。文字だけでは思い出す手がかりにならない。
    @Test func 久しぶりの料理に写真が付く() async throws {
        let (useCase, meals, dishes) = make()
        let photoID = UUID()
        let meal = MealRecord(occurredAt: daysAgo(60)).addingPhoto(photoID)
        try await meals.save(meal)
        let dish = Dish(name: try name("ハンバーグ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: daysAgo(60))
        )

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.first?.latestPhotoID == photoID)
    }

    @Test func 写真の無い記録でも久しぶりに出る() async throws {
        let (useCase, meals, dishes) = make()
        let meal = MealRecord(occurredAt: daysAgo(60))
        try await meals.save(meal)
        let dish = Dish(name: try name("ハンバーグ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: daysAgo(60))
        )

        let content = try await useCase.execute(now: now)

        #expect(content.forgottenDishes.count == 1)
        #expect(content.forgottenDishes.first?.latestPhotoID == nil)
    }

    /// 全件を読むと記録が増えるほど重くなる。上限で打ち切る。
    @Test func 通算件数は上限で打ち切る() async throws {
        let (useCase, meals, _) = make()
        for index in 0..<(GetHomeContentUseCase.totalCountCap + 20) {
            try await meals.save(
                MealRecord(occurredAt: now.addingTimeInterval(-Double(index) * 3600))
            )
        }

        let content = try await useCase.execute(now: now)

        #expect(content.summary.totalRecords >= GetHomeContentUseCase.totalCountCap)
    }
}
