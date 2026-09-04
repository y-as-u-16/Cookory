import Foundation

/// カレンダー表示専用の読み取り。
///
/// 「その月の日別サムネイル」は画面都合の集計で、MealRecordRepository に足すと
/// 集約の窓口が画面のために肥大化する。Query として分離する（ARCHITECTURE.md #19-22）。
protocol CalendarMealQuery: Sendable {
    /// 指定した月の日別サマリーを返す。記録のある日だけを含む。
    ///
    /// - Parameter calendar: 月の境界判定に使う。タイムゾーンを明示するために受け取る。
    func daySummaries(year: Int, month: Int, calendar: Calendar) async throws -> [CalendarDaySummary]

    /// 指定した日の記録を返す。
    func meals(on date: Date, calendar: Calendar) async throws -> [MealRecord]
}

/// カレンダーの 1 マス分。
struct CalendarDaySummary: Equatable, Sendable, Identifiable {
    /// その日の始まり。カレンダーの basis となるタイムゾーンで切り出す。
    let date: Date
    let mealCount: Int
    let thumbnailID: UUID?

    var id: Date { date }
}
