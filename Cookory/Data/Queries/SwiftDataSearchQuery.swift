import Foundation
import SwiftData

/// SearchQuery の SwiftData 実装。
struct SwiftDataSearchQuery: SearchQuery {
    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    func search(keyword: String, limit: Int) async throws -> SearchResults {
        // 空白だけの入力で全件を返さない。
        guard let normalized = keyword.normalizedOrNil, limit > 0 else { return .empty }

        return try await withPersistenceError {
            try await store.perform { context in
                SearchResults(
                    dishes: try searchDishes(normalized, limit: limit, in: context),
                    meals: try searchMeals(normalized, limit: limit, in: context)
                )
            }
        }
    }

    private func searchDishes(
        _ keyword: String, limit: Int, in context: ModelContext
    ) throws -> [CookbookItem] {
        var descriptor = FetchDescriptor<DishModel>(
            predicate: #Predicate { $0.name.localizedStandardContains(keyword) },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        let models = try context.fetch(descriptor)

        // 該当した料理の履歴だけを 1 度に読む。件数を出すために必要。
        let ids = Set(models.map(\.id))
        let logs = try context.fetch(FetchDescriptor<DishLogModel>(
            predicate: #Predicate { ids.contains($0.dishID) },
            sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
        ))

        var logsByDish: [UUID: [DishLogModel]] = [:]
        for log in logs {
            logsByDish[log.dishID, default: []].append(log)
        }

        return try models.map { model in
            let dishLogs = logsByDish[model.id] ?? []
            return CookbookItem(
                dish: try model.toDomain(),
                cookCount: dishLogs.count,
                lastCookedAt: dishLogs.first?.cookedAt,
                latestPhotoID: nil
            )
        }
    }

    private func searchMeals(
        _ keyword: String, limit: Int, in context: ModelContext
    ) throws -> [MealRecord] {
        var descriptor = FetchDescriptor<MealRecordModel>(
            predicate: #Predicate { $0.note?.localizedStandardContains(keyword) ?? false },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { $0.toDomain() }
    }
}
