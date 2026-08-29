import Foundation

/// ある料理を作った 1 回分の記録。
///
/// Dish と MealRecord を繋ぐ。同じ Dish に対して DishLog が積み重なることで、
/// 「12 回作った」「前回は味が濃かった」という履歴が表現できる。
struct DishLog: Identifiable, Hashable, Sendable {
    let id: UUID
    let dishID: UUID
    let mealRecordID: UUID
    var rating: DishRating?
    var note: String?
    let cookedAt: Date

    init(
        id: UUID = UUID(),
        dishID: UUID,
        mealRecordID: UUID,
        rating: DishRating? = nil,
        note: String? = nil,
        cookedAt: Date
    ) {
        self.id = id
        self.dishID = dishID
        self.mealRecordID = mealRecordID
        self.rating = rating
        self.note = note?.normalizedOrNil
        self.cookedAt = cookedAt
    }

    func rated(_ newRating: DishRating?) -> DishLog {
        var copy = self
        copy.rating = newRating
        return copy
    }

    func noted(_ newNote: String?) -> DishLog {
        var copy = self
        copy.note = newNote?.normalizedOrNil
        return copy
    }
}

extension String {
    /// 空白だけの文字列を nil として扱う。UI の空欄と「メモ無し」を同一視するため。
    var normalizedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
