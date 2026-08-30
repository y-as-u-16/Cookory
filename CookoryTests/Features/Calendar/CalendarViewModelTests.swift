import Foundation
import Testing
@testable import Cookory

@MainActor
struct CalendarViewModelTests {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ iso: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = tokyo.timeZone
        return try #require(formatter.date(from: iso))
    }

    @Test func 表示月は起点の月になる() throws {
        let viewModel = CalendarViewModel(
            query: StubCalendarMealQuery(), calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        #expect(viewModel.displayedMonth == (try date("2026-08-01 00:00")))
    }

    @Test func その月の日数だけ並ぶ() throws {
        let viewModel = CalendarViewModel(
            query: StubCalendarMealQuery(), calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        #expect(viewModel.daysInDisplayedMonth.count == 31)
    }

    @Test func 前の月へ移動できる() async throws {
        let viewModel = CalendarViewModel(
            query: StubCalendarMealQuery(), calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        await viewModel.showPreviousMonth()

        #expect(viewModel.displayedMonth == (try date("2026-07-01 00:00")))
        #expect(viewModel.daysInDisplayedMonth.count == 31)
    }

    @Test func 次の月へ移動できる() async throws {
        let viewModel = CalendarViewModel(
            query: StubCalendarMealQuery(), calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        await viewModel.showNextMonth()

        #expect(viewModel.displayedMonth == (try date("2026-09-01 00:00")))
        #expect(viewModel.daysInDisplayedMonth.count == 30)
    }

    @Test func 日付を選ぶとその日の記録が入る() async throws {
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-05 00:00")
        await query.setMeals([MealRecord(occurredAt: try date("2026-08-05 19:00"))], on: day)
        let viewModel = CalendarViewModel(
            query: query, calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        await viewModel.select(try date("2026-08-05 19:00"))

        #expect(viewModel.selectedDate == day)
        #expect(viewModel.selectedDayMeals.count == 1)
    }

    /// 月を移動したら前の月の選択は消す。別の月の記録が残ると誤解を招く。
    @Test func 月を移動すると選択が解除される() async throws {
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-05 00:00")
        await query.setMeals([MealRecord(occurredAt: day)], on: day)
        let viewModel = CalendarViewModel(
            query: query, calendar: tokyo, now: try date("2026-08-15 12:00")
        )
        await viewModel.select(day)

        await viewModel.showNextMonth()

        #expect(viewModel.selectedDate == nil)
        #expect(viewModel.selectedDayMeals.isEmpty)
    }

    @Test func サマリーを日付で引ける() async throws {
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-05 00:00")
        await query.setSummaries(
            [CalendarDaySummary(date: day, mealCount: 2, thumbnailID: nil)], year: 2026, month: 8
        )
        let viewModel = CalendarViewModel(
            query: query, calendar: tokyo, now: try date("2026-08-15 12:00")
        )
        await viewModel.load()

        #expect(viewModel.summary(for: try date("2026-08-05 19:00"))?.mealCount == 2)
        #expect(viewModel.summary(for: try date("2026-08-06 19:00")) == nil)
    }

    @Test func 読み込みに失敗するとメッセージが入る() async throws {
        let query = StubCalendarMealQuery()
        await query.setError(.persistenceFailed)
        let viewModel = CalendarViewModel(
            query: query, calendar: tokyo, now: try date("2026-08-15 12:00")
        )

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("DomainError") == false)
    }
}
