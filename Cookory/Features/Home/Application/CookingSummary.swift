import Foundation

/// 記録が積み上がっている実感を出すための集計。
///
/// 連続日数（ストリーク）は使わない。料理は毎日するとは限らず、
/// 途切れた瞬間に「失敗した」と感じさせるため。代わりに直近 7 日と
/// 通算の件数で「続いている」ことだけを伝える。
struct CookingSummary: Equatable, Sendable {
    /// 直近 7 日間に記録した日数。0〜7。
    let daysCookedThisWeek: Int

    /// 通算の記録件数。
    let totalRecords: Int

    /// 登録されている料理の種類。
    let distinctDishes: Int

    static let empty = CookingSummary(
        daysCookedThisWeek: 0, totalRecords: 0, distinctDishes: 0
    )

    /// 数字を出すに値するか。記録が少ないうちは出さない。
    ///
    /// 1 件で「1品」と出すのは、達成感より物足りなさを与える。
    var isWorthShowing: Bool { totalRecords >= 3 }
}

extension CookingSummary {
    /// 直近 7 日の記録から週の記録日数を数える。
    ///
    /// 同じ日に複数回記録しても 1 日として数える。回数ではなく
    /// 「何日料理したか」のほうが実感に近いため。
    static func make(
        recentMeals: [MealRecord],
        totalRecords: Int,
        distinctDishes: Int,
        now: Date,
        calendar: Calendar
    ) -> CookingSummary {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)

        let days = Set(
            recentMeals
                .filter { $0.occurredAt >= weekStart }
                .map { calendar.startOfDay(for: $0.occurredAt) }
        )

        return CookingSummary(
            daysCookedThisWeek: days.count,
            totalRecords: totalRecords,
            distinctDishes: distinctDishes
        )
    }
}
