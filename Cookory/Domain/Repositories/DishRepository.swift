import Foundation

/// 料理とその調理履歴の永続化。
///
/// DishLog を独立した Repository に切り出していないのは、DishLog が Dish なしでは
/// 存在し得ないため。Dish を集約の境界とし、その内側を一つの窓口で扱う。
protocol DishRepository: Sendable {
    func find(id: UUID) async throws -> Dish?

    /// 登録済みの料理をすべて返す。Cookbook や「久しぶりの料理」の集計に使う。
    /// 料理の種類は記録の件数ほどには増えないため上限を設けない。
    func fetchAll() async throws -> [Dish]

    /// 同じ料理名の Dish を重複させないために使う。
    /// 「唐揚げ」を二度記録しても Dish は 1 件のままにする（APP_DESIGN.md #11）。
    func find(name: DishName) async throws -> Dish?

    func save(_ dish: Dish) async throws

    /// 紐づく DishLog もあわせて削除する。
    func delete(id: UUID) async throws

    /// ある料理の調理履歴を新しい順に返す。
    func fetchLogs(dishID: UUID) async throws -> [DishLog]

    /// ある食事記録に紐づく調理履歴を返す。
    func fetchLogs(mealRecordID: UUID) async throws -> [DishLog]

    func save(_ log: DishLog) async throws

    func deleteLog(id: UUID) async throws
}
