import Foundation
import SwiftData

/// PhotoAsset の永続化表現。
///
/// 画像の実体は ImageStorage がファイルとして持ち、ここにはメタデータだけを置く。
@Model
final class PhotoAssetModel {
    @Attribute(.unique) var id: UUID
    var filename: String
    var width: Int
    var height: Int
    var createdAt: Date

    init(id: UUID, filename: String, width: Int, height: Int, createdAt: Date) {
        self.id = id
        self.filename = filename
        self.width = width
        self.height = height
        self.createdAt = createdAt
    }
}
