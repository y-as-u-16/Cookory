import Foundation

/// 撮影した写真のメタデータ。
///
/// 画像の実体は保持しない。`URL` や `Data` を持つと Domain がファイルシステムに
/// 依存するため、実体の読み書きは Data 層の ImageStorage が担う。
struct PhotoAsset: Identifiable, Hashable, Sendable {
    let id: UUID
    let filename: String
    let width: Int
    let height: Int
    let createdAt: Date

    init(id: UUID = UUID(), filename: String, width: Int, height: Int, createdAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.width = width
        self.height = height
        self.createdAt = createdAt
    }
}
