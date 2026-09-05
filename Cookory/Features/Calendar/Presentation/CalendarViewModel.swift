import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    private(set) var summaries: [CalendarDaySummary] = []
    private(set) var selectedDayMeals: [CalendarMeal] = []
    private(set) var selectedDate: Date?
    private(set) var errorMessage: LocalizedStringResource?

    /// 表示中の月の 1 日。
    private(set) var displayedMonth: Date

    private let query: CalendarMealQuery
    private let deleteMealRecord: DeleteMealRecordUseCase
    private let calendar: Calendar

    /// - Parameter calendar: 月の境界判定に使う。端末設定でずれないようテストから差し替える。
    init(
        query: CalendarMealQuery,
        deleteMealRecord: DeleteMealRecordUseCase,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.query = query
        self.deleteMealRecord = deleteMealRecord
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
            errorMessage = L10n.errorLoad
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
            errorMessage = L10n.errorLoad
        }
    }

    /// 記録を消す。写真と調理履歴も一緒に消える。
    func delete(mealID: UUID) async {
        do {
            try await deleteMealRecord.execute(id: mealID)
            errorMessage = nil
            await reload()
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    /// 表示中の内容を取り直す。
    ///
    /// 詳細画面で記録を消して戻ったとき、消えたはずの記録が残らないようにする。
    /// `.task` は画面を積み直すまで再実行されないため、戻り際に明示して呼ぶ。
    func reload() async {
        await load()
        guard let selectedDate else { return }
        await select(selectedDate)
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

    /// 週の並びに合わせるため、月初の前に入れる空きマスの数。
    /// これが無いと 1 日が常に左端に来て、曜日と日付がずれる。
    var leadingBlankCount: Int {
        let weekday = calendar.component(.weekday, from: displayedMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// 曜日の見出し。firstWeekday はロケールで変わるため並べ替える。
    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
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
