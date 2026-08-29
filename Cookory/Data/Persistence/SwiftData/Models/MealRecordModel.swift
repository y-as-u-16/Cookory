import Foundation
import SwiftData

/// MealRecord の永続化表現。
///
/// 関連を `@Relationship` ではなく ID の配列で持つ。Domain の MealRecord が
/// 既に ID で関連を表しており、オブジェクト参照を挟むと Model → Domain の
/// 変換時に SwiftData のオブジェクト同一性が Domain へ漏れるため。
@Model
final class MealRecordModel {
    #Index<MealRecordModel>([\.occurredAt])

    @Attribute(.unique) var id: UUID
    var occurredAt: Date
    var mealTypeRawValue: String?
    var note: String?
    var photoIDs: [UUID]
    var dishLogIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        occurredAt: Date,
        mealTypeRawValue: String?,
        note: String?,
        photoIDs: [UUID],
        dishLogIDs: [UUID],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.mealTypeRawValue = mealTypeRawValue
        self.note = note
        self.photoIDs = photoIDs
        self.dishLogIDs = dishLogIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
