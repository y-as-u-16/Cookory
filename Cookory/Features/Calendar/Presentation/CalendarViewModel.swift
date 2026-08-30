import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    private(set) var summaries: [CalendarDaySummary] = []
    private(set) var selectedDayMeals: [MealRecord] = []
    private(set) var selectedDate: Date?
    private(set) var errorMessage: String?

    /// 表示中の月の 1 日。
    private(set) var displayedMonth: Date

    private let query: CalendarMealQuery
    private let calendar: Calendar

    /// - Parameter calendar: 月の境界判定に使う。端末設定でずれないようテストから差し替える。
    init(query: CalendarMealQuery, calendar: Calendar = .current, now: Date = Date()) {
        self.query = query
        self.calendar = calendar
        self.displayedMonth = calendar.startOfMonth(for: now)
    }

    func load() async {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let year = components.year, let month = components.month else { return }

        do {
            summaries = try await query.daySummaries(year: year, month: month, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = "読み込めませんでした。もう一度お試しください。"
        }
    }

    func showPreviousMonth() async {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = previous
        clearSelection()
        await load()
    }

    func showNextMonth() async {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        clearSelection()
        await load()
    }

    func select(_ date: Date) async {
        selectedDate = calendar.startOfDay(for: date)
        do {
            selectedDayMeals = try await query.meals(on: date, calendar: calendar)
            errorMessage = nil
        } catch {
            selectedDayMeals = []
            errorMessage = "読み込めませんでした。もう一度お試しください。"
        }
    }

    func summary(for date: Date) -> CalendarDaySummary? {
        let day = calendar.startOfDay(for: date)
        return summaries.first { $0.date == day }
    }

    /// その月に並べる日付。週の頭揃えは View の責務なので日付だけ返す。
    var daysInDisplayedMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
        }
    }

    private func clearSelection() {
        selectedDate = nil
        selectedDayMeals = []
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
