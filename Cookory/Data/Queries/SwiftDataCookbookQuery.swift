import Foundation
import SwiftData

/// CookbookQuery の SwiftData 実装。
struct SwiftDataCookbookQuery: CookbookQuery {
    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    func items(sort: CookbookSort, limit: Int, offset: Int) async throws -> [CookbookItem] {
        guard limit > 0 else { return [] }

        let items = try await withPersistenceError {
            try await store.perform { context in
                let dishes = try context.fetch(FetchDescriptor<DishModel>())
                let logs = try context.fetch(FetchDescriptor<DishLogModel>(
                    sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
                ))

                // 1 件ずつ fetchLogs を呼ぶと料理の数だけクエリが飛ぶ。
                // 全件を 1 度読んで畳む。
                var logsByDish: [UUID: [DishLogModel]] = [:]
                for log in logs {
                    logsByDish[log.dishID, default: []].append(log)
                }

                // 最新の履歴が属する食事記録から写真を引く。
                let meals = try context.fetch(FetchDescriptor<MealRecordModel>())
                let photoByMeal = Dictionary(
                    meals.map { ($0.id, $0.photoIDs.first) }, uniquingKeysWith: { first, _ in first }
                )

                // 作った料理だけを並べる。履歴の無い Dish は図鑑に出さない。
                return try dishes.compactMap { model -> CookbookItem? in
                    guard let dishLogs = logsByDish[model.id], !dishLogs.isEmpty else { return nil }
                    return CookbookItem(
                        dish: try model.toDomain(),
                        cookCount: dishLogs.count,
                        lastCookedAt: dishLogs.first?.cookedAt,
                        latestPhotoID: dishLogs.first.flatMap { photoByMeal[$0.mealRecordID] } ?? nil
                    )
                }
            }
        }

        return Self.sorted(items, by: sort)
            .dropFirst(offset)
            .prefix(limit)
            .map { $0 }
    }

    static func sorted(_ items: [CookbookItem], by sort: CookbookSort) -> [CookbookItem] {
        switch sort {
        case .recentlyCooked:
            return items.sorted { ($0.lastCookedAt ?? .distantPast) > ($1.lastCookedAt ?? .distantPast) }
        case .mostCooked:
            // 回数が同じなら名前順にする。並びが実行ごとに変わると探しにくい。
            return items.sorted {
                $0.cookCount == $1.cookCount
                    ? $0.dish.name.value < $1.dish.name.value
                    : $0.cookCount > $1.cookCount
            }
        case .notCookedRecently:
            return items.sorted { ($0.lastCookedAt ?? .distantPast) < ($1.lastCookedAt ?? .distantPast) }
        case .favorite:
            return items.sorted {
                $0.dish.isFavorite == $1.dish.isFavorite
                    ? $0.dish.name.value < $1.dish.name.value
                    : $0.dish.isFavorite
            }
        case .name:
            return items.sorted { $0.dish.name.value < $1.dish.name.value }
        }
    }
}
