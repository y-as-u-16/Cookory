import Foundation

/// Home 画面の内容を組み立てる。
///
/// Query として分離していない。Repository のメソッドで書けるうちは
/// それでよい（ARCHITECTURE.md #75）。集計が重くなったら昇格させる。
struct GetHomeContentUseCase: Sendable {
    /// 「久しぶり」と見なす日数。
    static let forgottenThresholdDays = 30
    static let recentMealLimit = 10
    static let forgottenDishLimit = 6

    /// 通算件数を数える上限。これを超えたら「たくさん」として扱えば足りる。
    static let totalCountCap = 500
    static let countPageSize = 100

    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    func execute(now: Date = Date(), calendar: Calendar = .current) async throws -> HomeContent {
        let recent = try await recentMeals()
        let dishes = try await dishRepository.fetchAll()

        return HomeContent(
            recentMeals: recent,
            forgottenDishes: try await forgottenDishes(
                dishes, now: now, calendar: calendar
            ),
            summary: CookingSummary.make(
                recentMeals: recent.map(\.meal),
                totalRecords: try await totalRecordCount(),
                distinctDishes: dishes.count,
                now: now,
                calendar: calendar
            )
        )
    }

    /// 通算の記録件数。上限まで数えて、それ以上は「上限以上」として扱う。
    /// 全件を数えるために全件を読むのは、記録が増えるほど重くなる。
    private func totalRecordCount() async throws -> Int {
        var total = 0
        var offset = 0
        while total < Self.totalCountCap {
            let page = try await mealRepository.fetchPage(
                offset: offset, limit: Self.countPageSize
            )
            guard !page.isEmpty else { break }
            total += page.count
            offset += page.count
        }
        return total
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

    private func forgottenDishes(
        _ dishes: [Dish], now: Date, calendar: Calendar
    ) async throws -> [ForgottenDish] {
        var candidates: [ForgottenDish] = []

        for dish in dishes {
            // 一度も作っていない料理は「久しぶり」ではない。
            guard let latest = try await dishRepository.fetchLogs(dishID: dish.id).first
            else { continue }

            let days = calendar.dateComponents(
                [.day], from: latest.cookedAt, to: now
            ).day ?? 0
            guard days >= Self.forgottenThresholdDays else { continue }

            let photoID = try await mealRepository
                .find(id: latest.mealRecordID)?.photoIDs.first

            candidates.append(ForgottenDish(
                dish: dish,
                lastCookedAt: latest.cookedAt,
                daysSinceLastCooked: days,
                latestPhotoID: photoID
            ))
        }

        return candidates
            .sorted { $0.daysSinceLastCooked > $1.daysSinceLastCooked }
            .prefix(Self.forgottenDishLimit)
            .map { $0 }
    }
}
