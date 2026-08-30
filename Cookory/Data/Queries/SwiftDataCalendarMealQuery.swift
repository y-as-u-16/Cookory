import Foundation
import SwiftData

/// CalendarMealQuery の SwiftData 実装。
struct SwiftDataCalendarMealQuery: CalendarMealQuery {
    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    func daySummaries(
        year: Int, month: Int, calendar: Calendar
    ) async throws -> [CalendarDaySummary] {
        guard let range = Self.monthRange(year: year, month: month, calendar: calendar) else {
            return []
        }

        let models = try await withPersistenceError {
            let start = range.start
            let end = range.end
            return try await store.fetch(FetchDescriptor<MealRecordModel>(
                predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
                sortBy: [SortDescriptor(\.occurredAt)]
            ))
        }

        // 日単位に畳む。境界の判定は渡された calendar のタイムゾーンに従う。
        var byDay: [Date: (count: Int, thumbnailID: UUID?)] = [:]
        for model in models {
            let day = calendar.startOfDay(for: model.occurredAt)
            let existing = byDay[day]
            byDay[day] = (
                count: (existing?.count ?? 0) + 1,
                thumbnailID: existing?.thumbnailID ?? model.photoIDs.first
            )
        }

        return byDay
            .map { CalendarDaySummary(date: $0.key, mealCount: $0.value.count, thumbnailID: $0.value.thumbnailID) }
            .sorted { $0.date < $1.date }
    }

    func meals(on date: Date, calendar: Calendar) async throws -> [MealRecord] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        return try await withPersistenceError {
            try await store.fetch(FetchDescriptor<MealRecordModel>(
                predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
                sortBy: [SortDescriptor(\.occurredAt)]
            )).map { $0.toDomain() }
        }
    }

    /// 月の開始と終了。端末のタイムゾーン設定で表示がずれないよう calendar を使う。
    static func monthRange(
        year: Int, month: Int, calendar: Calendar
    ) -> (start: Date, end: Date)? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
        return (start, end)
    }
}
