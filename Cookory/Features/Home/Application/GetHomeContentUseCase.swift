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
            recentMeals: try await mealRepository.fetchRecent(limit: Self.recentMealLimit),
            forgottenDishes: try await forgottenDishes(now: now, calendar: calendar)
        )
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
