import Foundation

/// Home 画面の内容を組み立てる。
///
/// Query として分離していない。Repository のメソッドで書けるうちは
/// それでよい（ARCHITECTURE.md #75）。集計が重くなったら昇格させる。
struct GetHomeContentUseCase: Sendable {
    /// 「久しぶり」と見なす日数。
    static let forgottenThresholdDays = 30
    static let recentMealLimit = 10
    static let forgottenDishLimit = 3

    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    func execute(now: Date = Date(), calendar: Calendar = .current) async throws -> HomeContent {
        HomeContent(
            recentMeals: try await recentMeals(),
            forgottenDishes: try await forgottenDishes(now: now, calendar: calendar)
        )
    }

    /// 記録に紐づく料理名を解決する。
    private func recentMeals() async throws -> [RecentMeal] {
        var results: [RecentMeal] = []

        for meal in try await mealRepository.fetchRecent(limit: Self.recentMealLimit) {
            var names: [DishName] = []
            for log in try await dishRepository.fetchLogs(mealRecordID: meal.id) {
                if let dish = try await dishRepository.find(id: log.dishID) {
                    names.append(dish.name)
                }
            }
            results.append(RecentMeal(meal: meal, dishNames: names))
        }

        return results
    }

    private func forgottenDishes(now: Date, calendar: Calendar) async throws -> [ForgottenDish] {
        var candidates: [ForgottenDish] = []

        for dish in try await dishRepository.fetchAll() {
            // 一度も作っていない料理は「久しぶり」ではない。
            guard let lastCookedAt = try await dishRepository
                .fetchLogs(dishID: dish.id).first?.cookedAt else { continue }

            let days = calendar.dateComponents([.day], from: lastCookedAt, to: now).day ?? 0
            guard days >= Self.forgottenThresholdDays else { continue }

            candidates.append(
                ForgottenDish(dish: dish, lastCookedAt: lastCookedAt, daysSinceLastCooked: days)
            )
        }

        return candidates
            .sorted { $0.daysSinceLastCooked > $1.daysSinceLastCooked }
            .prefix(Self.forgottenDishLimit)
            .map { $0 }
    }
}
