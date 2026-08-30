import Foundation

/// 食事記録の永続化。
///
/// 画面都合の取得メソッドは足さない。カレンダーの月別集計のような
/// 表示専用の読み取りは Query として分離する（ARCHITECTURE.md #19-22）。
protocol MealRecordRepository: Sendable {
    func find(id: UUID) async throws -> MealRecord?

    /// 新しい順に取得する。`limit` は一覧表示で全件をメモリに載せないための上限。
    func fetchRecent(limit: Int) async throws -> [MealRecord]

    /// 古い順にページ単位で取得する。Export のように全件を扱う処理で使う。
    /// 一度に全件を返さないのは、数千件でも端末が固まらないようにするため。
    func fetchPage(offset: Int, limit: Int) async throws -> [MealRecord]

    func save(_ meal: MealRecord) async throws

    /// 存在しない ID を渡しても失敗させない。削除の再実行を安全にするため。
    func delete(id: UUID) async throws
}
