import Foundation
import Testing
@testable import Cookory

struct CookingSummaryTests {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    @Test func 記録が無ければ0になる() {
        let summary = CookingSummary.make(
            recentMeals: [], totalRecords: 0, distinctDishes: 0, now: now, calendar: tokyo
        )

        #expect(summary.daysCookedThisWeek == 0)
        #expect(!summary.isWorthShowing)
    }

    /// 同じ日に複数回記録しても 1 日として数える。
    /// 回数ではなく「何日料理したか」のほうが実感に近い。
    @Test func 同じ日の複数記録は1日として数える() {
        let meals = [
            MealRecord(occurredAt: daysAgo(1)),
            MealRecord(occurredAt: daysAgo(1).addingTimeInterval(3600)),
            MealRecord(occurredAt: daysAgo(1).addingTimeInterval(7200)),
        ]

        let summary = CookingSummary.make(
            recentMeals: meals, totalRecords: 3, distinctDishes: 1, now: now, calendar: tokyo
        )

        #expect(summary.daysCookedThisWeek == 1)
    }

    @Test func 週の日数を数える() {
        let meals = [1, 3, 5].map { MealRecord(occurredAt: daysAgo($0)) }

        let summary = CookingSummary.make(
            recentMeals: meals, totalRecords: 3, distinctDishes: 3, now: now, calendar: tokyo
        )

        #expect(summary.daysCookedThisWeek == 3)
    }

    /// 7 日より前の記録は週の集計に含めない。
    @Test func 八日前の記録は週に含めない() {
        let meals = [
            MealRecord(occurredAt: daysAgo(1)),
            MealRecord(occurredAt: daysAgo(8)),
            MealRecord(occurredAt: daysAgo(30)),
        ]

        let summary = CookingSummary.make(
            recentMeals: meals, totalRecords: 3, distinctDishes: 3, now: now, calendar: tokyo
        )

        #expect(summary.daysCookedThisWeek == 1)
    }

    @Test func 週の日数は7を超えない() {
        let meals = (0..<7).map { MealRecord(occurredAt: daysAgo($0)) }

        let summary = CookingSummary.make(
            recentMeals: meals, totalRecords: 7, distinctDishes: 7, now: now, calendar: tokyo
        )

        #expect(summary.daysCookedThisWeek == 7)
    }

    /// 1 件で「1品」と出すのは達成感より物足りなさを与える。
    @Test func 記録が少ないうちは出さない() {
        for count in 0...2 {
            let summary = CookingSummary(
                daysCookedThisWeek: 1, totalRecords: count, distinctDishes: 1
            )
            #expect(!summary.isWorthShowing)
        }

        #expect(CookingSummary(
            daysCookedThisWeek: 1, totalRecords: 3, distinctDishes: 1
        ).isWorthShowing)
    }
}
