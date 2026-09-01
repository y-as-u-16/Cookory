import Foundation
import Testing
@testable import Cookory

/// カレンダーからの削除と、戻ってきたときの取り直しを確かめる。
@MainActor
struct CalendarDeletionTests {
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

    private func make(
        query: StubCalendarMealQuery,
        meals: InMemoryMealRecordRepository,
        dishes: InMemoryDishRepository = InMemoryDishRepository(),
        storage: InMemoryImageStorage = InMemoryImageStorage(),
        now: Date
    ) -> CalendarViewModel {
        CalendarViewModel(
            query: query,
            deleteMealRecord: DeleteMealRecordUseCase(
                mealRepository: meals, dishRepository: dishes, imageStorage: storage
            ),
            calendar: tokyo,
            now: now
        )
    }

    @Test func 記録を削除できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-15 00:00")
        let meal = MealRecord(occurredAt: try date("2026-08-15 12:00"))
        try await meals.save(meal)
        await query.setMeals([meal], on: day)

        let viewModel = make(query: query, meals: meals, now: try date("2026-08-15 12:00"))
        await viewModel.select(day)
        #expect(viewModel.selectedDayMeals.count == 1)

        // 消えた状態を Query にも反映させる。実際の Query は DB を見ている。
        await query.setMeals([], on: day)
        await viewModel.delete(mealID: meal.id)

        #expect(try await meals.find(id: meal.id) == nil)
        #expect(viewModel.selectedDayMeals.isEmpty)
    }

    @Test func 削除に失敗するとエラーを出す() async throws {
        let meals = InMemoryMealRecordRepository()
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-15 00:00")
        let meal = MealRecord(occurredAt: try date("2026-08-15 12:00"))
        try await meals.save(meal)
        await query.setMeals([meal], on: day)

        let viewModel = make(query: query, meals: meals, now: try date("2026-08-15 12:00"))
        await viewModel.select(day)
        await meals.setError(.persistenceFailed)

        await viewModel.delete(mealID: meal.id)

        #expect(viewModel.errorMessage != nil)
    }

    /// 詳細画面で消して戻ったとき、一覧に残らないようにする。
    @Test func 再読み込みで選択中の日も取り直す() async throws {
        let meals = InMemoryMealRecordRepository()
        let query = StubCalendarMealQuery()
        let day = try date("2026-08-15 00:00")
        let meal = MealRecord(occurredAt: try date("2026-08-15 12:00"))
        await query.setMeals([meal], on: day)

        let viewModel = make(query: query, meals: meals, now: try date("2026-08-15 12:00"))
        await viewModel.select(day)
        #expect(viewModel.selectedDayMeals.count == 1)

        // 別画面で消された状態。
        await query.setMeals([], on: day)
        await viewModel.reload()

        #expect(viewModel.selectedDayMeals.isEmpty)
    }

    @Test func 日付を選んでいなければ再読み込みしても壊れない() async throws {
        let viewModel = make(
            query: StubCalendarMealQuery(),
            meals: InMemoryMealRecordRepository(),
            now: try date("2026-08-15 12:00")
        )

        await viewModel.reload()

        #expect(viewModel.selectedDate == nil)
        #expect(viewModel.selectedDayMeals.isEmpty)
    }
}
