import Foundation

/// ある料理の調理履歴をまとめて取る。
///
/// 「同じ料理の評価とメモが時系列で並ぶ」ことがこのアプリの中核価値。
/// 履歴に写真を添えるため、DishLog から食事記録を辿って写真 ID を解決する。
struct GetDishHistoryUseCase: Sendable {
    private let dishRepository: DishRepository
    private let mealRepository: MealRecordRepository

    init(dishRepository: DishRepository, mealRepository: MealRecordRepository) {
        self.dishRepository = dishRepository
        self.mealRepository = mealRepository
    }

    func execute(dishID: UUID) async throws -> DishHistory {
        guard let dish = try await dishRepository.find(id: dishID) else {
            throw DomainError.notFound(id: dishID)
        }

        let logs = try await dishRepository.fetchLogs(dishID: dishID)

        let meals = try await mealRepository.find(ids: logs.map(\.mealRecordID))
        let entries = logs.map {
            DishHistoryEntry(log: $0, photoID: meals[$0.mealRecordID]?.photoIDs.first)
        }

        return DishHistory(dish: dish, entries: entries)
    }

    /// お気に入りを切り替える。
    @discardableResult
    func toggleFavorite(dishID: UUID, now: Date = Date()) async throws -> Dish {
        guard let dish = try await dishRepository.find(id: dishID) else {
            throw DomainError.notFound(id: dishID)
        }
        let updated = dish.favoriteToggled(at: now)
        try await dishRepository.save(updated)
        return updated
    }
}

/// 料理とその履歴。
struct DishHistory: Equatable, Sendable {
    let dish: Dish
    let entries: [DishHistoryEntry]

    var cookCount: Int { entries.count }

    /// 最終調理日。履歴は新しい順に並ぶ。
    var lastCookedAt: Date? { entries.first?.log.cookedAt }

    /// 一覧の先頭に出す写真。履歴が写真無しでも次を探す。
    var latestPhotoID: UUID? { entries.compactMap(\.photoID).first }
}

/// 履歴の 1 件。
struct DishHistoryEntry: Equatable, Sendable, Identifiable {
    let log: DishLog
    let photoID: UUID?

    var id: UUID { log.id }
}
