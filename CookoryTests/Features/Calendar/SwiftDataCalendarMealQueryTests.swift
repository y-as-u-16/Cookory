import Foundation
import Testing
@testable import Cookory

struct SwiftDataCalendarMealQueryTests {
    private func make() throws -> (SwiftDataCalendarMealQuery, SwiftDataMealRecordRepository) {
        let store = try SwiftDataStore.makeInMemory()
        return (SwiftDataCalendarMealQuery(store: store), SwiftDataMealRecordRepository(store: store))
    }

    /// 明示的にタイムゾーンを固定する。端末設定に依存させない。
    private func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    private var tokyo: Calendar { calendar(timeZoneID: "Asia/Tokyo") }

    private func date(_ iso: String, in calendar: Calendar) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = calendar.timeZone
        return try #require(formatter.date(from: iso))
    }

    @Test func 記録のある日だけ返る() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 12:00", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-20 19:00", in: tokyo)))

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries.count == 2)
    }

    @Test func 記録が無ければ空になる() async throws {
        let (query, _) = try make()

        #expect(try await query.daySummaries(year: 2026, month: 8, calendar: tokyo).isEmpty)
    }

    @Test func 同じ日の複数記録は件数に反映される() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 08:00", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 19:00", in: tokyo)))

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries.count == 1)
        #expect(summaries.first?.mealCount == 2)
    }

    @Test func 月をまたぐ記録は含まれない() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-07-31 23:00", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-01 00:30", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-09-01 00:30", in: tokyo)))

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries.count == 1)
    }

    /// 月末深夜の記録は、タイムゾーンによって属する月が変わる。
    /// Calendar を渡さず端末設定に任せると、旅行先で表示が崩れる。
    @Test func タイムゾーンで月の境界が変わる() async throws {
        let (query, meals) = try make()
        // 東京の 9/1 00:30 は UTC では 8/31 15:30。
        try await meals.save(MealRecord(occurredAt: try date("2026-09-01 00:30", in: tokyo)))

        let inTokyo = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)
        let inUTC = try await query.daySummaries(
            year: 2026, month: 8, calendar: calendar(timeZoneID: "UTC")
        )

        #expect(inTokyo.isEmpty)
        #expect(inUTC.count == 1)
    }

    @Test func サムネイルに写真IDが入る() async throws {
        let (query, meals) = try make()
        let photoID = UUID()
        try await meals.save(
            MealRecord(occurredAt: try date("2026-08-05 12:00", in: tokyo)).addingPhoto(photoID)
        )

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries.first?.thumbnailID == photoID)
    }

    @Test func 写真の無い記録はサムネイルがnil() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 12:00", in: tokyo)))

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries.first?.thumbnailID == nil)
    }

    @Test func 日別サマリーは日付順に並ぶ() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-08-20 12:00", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 12:00", in: tokyo)))

        let summaries = try await query.daySummaries(year: 2026, month: 8, calendar: tokyo)

        #expect(summaries[0].date < summaries[1].date)
    }

    @Test func 指定した日の記録を取得できる() async throws {
        let (query, meals) = try make()
        let target = try date("2026-08-05 12:00", in: tokyo)
        try await meals.save(MealRecord(occurredAt: target))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-06 12:00", in: tokyo)))

        let result = try await query.meals(on: target, calendar: tokyo)

        #expect(result.count == 1)
    }

    /// 日付だけでは何を作った日か分からない。一覧に名前を出すために返す。
    @Test func 記録に料理名が付く() async throws {
        let store = try SwiftDataStore.makeInMemory()
        let query = SwiftDataCalendarMealQuery(store: store)
        let meals = SwiftDataMealRecordRepository(store: store)
        let dishes = SwiftDataDishRepository(store: store)

        let target = try date("2026-08-05 12:00", in: tokyo)
        let meal = MealRecord(occurredAt: target)
        try await meals.save(meal)

        let nikujaga = Dish(name: try #require(DishName("肉じゃが")))
        let salad = Dish(name: try #require(DishName("サラダ")))
        try await dishes.save(nikujaga)
        try await dishes.save(salad)
        try await dishes.save(
            DishLog(dishID: nikujaga.id, mealRecordID: meal.id, cookedAt: target)
        )
        try await dishes.save(
            DishLog(dishID: salad.id, mealRecordID: meal.id, cookedAt: target)
        )

        let result = try await query.meals(on: target, calendar: tokyo)

        #expect(result.count == 1)
        #expect(Set(try #require(result.first).dishNames) == ["肉じゃが", "サラダ"])
    }

    @Test func 料理を紐づけていない記録は名前が空になる() async throws {
        let (query, meals) = try make()
        let target = try date("2026-08-05 12:00", in: tokyo)
        try await meals.save(MealRecord(occurredAt: target))

        let result = try await query.meals(on: target, calendar: tokyo)

        #expect(try #require(result.first).dishNames.isEmpty)
    }

    @Test func 日の境界は0時から24時までになる() async throws {
        let (query, meals) = try make()
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 00:00", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-05 23:59", in: tokyo)))
        try await meals.save(MealRecord(occurredAt: try date("2026-08-06 00:00", in: tokyo)))

        let result = try await query.meals(
            on: try date("2026-08-05 12:00", in: tokyo), calendar: tokyo
        )

        #expect(result.count == 2)
    }
}
