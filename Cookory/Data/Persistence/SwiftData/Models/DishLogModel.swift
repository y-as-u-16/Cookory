import Foundation
import SwiftData

/// DishLog の永続化表現。
@Model
final class DishLogModel {
    #Index<DishLogModel>([\.dishID], [\.mealRecordID])

    @Attribute(.unique) var id: UUID
    var dishID: UUID
    var mealRecordID: UUID
    var rating: Int?
    var note: String?
    var cookedAt: Date

    init(
        id: UUID,
        dishID: UUID,
        mealRecordID: UUID,
        rating: Int?,
        note: String?,
        cookedAt: Date
    ) {
        self.id = id
        self.dishID = dishID
        self.mealRecordID = mealRecordID
        self.rating = rating
        self.note = note
        self.cookedAt = cookedAt
    }
}
