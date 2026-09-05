import Foundation
@testable import Cookory

/// テスト用の CalendarMealQuery。返す値を直接指定する。
actor StubCalendarMealQuery: CalendarMealQuery {
    private var summariesByMonth: [String: [CalendarDaySummary]] = [:]
    private var mealsByDay: [Date: [CalendarMeal]] = [:]
    private var errorToThrow: DomainError?

    func daySummaries(
        year: Int, month: Int, calendar: Calendar
    ) async throws -> [CalendarDaySummary] {
        if let errorToThrow { throw errorToThrow }
        return summariesByMonth["\(year)-\(month)"] ?? []
    }

    func meals(on date: Date, calendar: Calendar) async throws -> [CalendarMeal] {
        if let errorToThrow { throw errorToThrow }
        return mealsByDay[calendar.startOfDay(for: date)] ?? []
    }

    func setSummaries(_ summaries: [CalendarDaySummary], year: Int, month: Int) {
        summariesByMonth["\(year)-\(month)"] = summaries
    }

    func setMeals(_ meals: [MealRecord], on day: Date, dishNames: [String] = []) {
        mealsByDay[day] = meals.map { CalendarMeal(meal: $0, dishNames: dishNames) }
    }

    func setCalendarMeals(_ meals: [CalendarMeal], on day: Date) {
        mealsByDay[day] = meals
    }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }
}
