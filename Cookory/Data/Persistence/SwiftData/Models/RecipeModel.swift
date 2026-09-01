import Foundation
import SwiftData

/// Recipe の永続化表現。
@Model
final class RecipeModel {
    #Index<RecipeModel>([\.dishID])

    @Attribute(.unique) var id: UUID
    var dishID: UUID
    var ingredients: String?
    var steps: String?

    /// リンクは JSON 文字列で持つ。件数が少なく、検索対象にもしないため
    /// 別モデルに切り出すコストに見合わない。
    var linksJSON: String?

    /// 添付したスクリーンショットの ID。リンクと同じ理由で JSON 文字列にする。
    /// Optional なので既存データは軽量マイグレーションで nil のまま読める。
    var photoIDsJSON: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        dishID: UUID,
        ingredients: String?,
        steps: String?,
        linksJSON: String?,
        photoIDsJSON: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.dishID = dishID
        self.ingredients = ingredients
        self.steps = steps
        self.linksJSON = linksJSON
        self.photoIDsJSON = photoIDsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
