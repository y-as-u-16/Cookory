import Foundation

extension DishLogModel {
    /// 範囲外の評価は nil に落とす。評価は任意項目なので、値が壊れていても
    /// 「評価なし」として記録全体を読めるほうが利用者の損失が小さい。
    func toDomain() -> DishLog {
        DishLog(
            id: id,
            dishID: dishID,
            mealRecordID: mealRecordID,
            rating: rating.flatMap(DishRating.init),
            note: note,
            cookedAt: cookedAt
        )
    }

    func update(from log: DishLog) {
        rating = log.rating?.value
        note = log.note
    }

    convenience init(from log: DishLog) {
        self.init(
            id: log.id,
            dishID: log.dishID,
            mealRecordID: log.mealRecordID,
            rating: log.rating?.value,
            note: log.note,
            cookedAt: log.cookedAt
        )
    }
}
