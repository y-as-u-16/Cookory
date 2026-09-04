import UIKit

/// デコード済みの写真を持ち回す。
///
/// 一覧をスクロールすると同じ写真が何度も表示される。都度ファイルを読んで
/// デコードすると、戻ってきた行がその場で作り直される。
///
/// 保持するのはデコード済みの `UIImage` で、実測のバイト数ではなく画素数から
/// おおよそのコストを与える。`NSCache` は memory warning で自動的に空になる。
///
/// 削除時の無効化は持たない。鍵が UUID なので消した ID は二度と現れず、
/// 無効化のために Application 層から UI 層を呼ぶと依存が逆流する。
final class PhotoImageCache: @unchecked Sendable {
    static let shared = PhotoImageCache()

    private let storage = NSCache<NSString, UIImage>()

    private init() {
        // 端末の空きに任せると一覧をたどるだけで数百 MB に達する。
        storage.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for photoID: UUID, maxDimension: Int) -> UIImage? {
        storage.object(forKey: Self.key(photoID, maxDimension))
    }

    func store(_ image: UIImage, for photoID: UUID, maxDimension: Int) {
        storage.setObject(
            image,
            forKey: Self.key(photoID, maxDimension),
            cost: Int(image.size.width * image.size.height * image.scale * image.scale) * 4
        )
    }

    /// 解像度ごとに別の実体を持つため、鍵に含める。
    private static func key(_ photoID: UUID, _ maxDimension: Int) -> NSString {
        "\(photoID.uuidString)-\(maxDimension)" as NSString
    }
}
