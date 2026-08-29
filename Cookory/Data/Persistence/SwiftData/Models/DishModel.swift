import Foundation
import SwiftData

/// Dish の永続化表現。
@Model
final class DishModel {
    #Index<DishModel>([\.name])

    @Attribute(.unique) var id: UUID
    /// DishName ではなく String で持つ。ValueObject を直接永続化すると
    /// 検証ルールの変更が既存データを読めなくする。
    var name: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, isFavorite: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
