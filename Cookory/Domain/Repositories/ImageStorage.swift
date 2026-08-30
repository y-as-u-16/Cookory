import Foundation

/// 写真の実体を扱う窓口。
///
/// Domain は Data を受け渡すだけで、保存先やフォーマットを知らない。
/// 将来 Cloud Storage へ移す際もこの protocol は変わらない。
protocol ImageStorage: Sendable {
    /// 画像を保存し、メタデータを返す。サムネイルも同時に生成する。
    func save(_ data: Data) async throws -> PhotoAsset

    /// 原本を読み出す。
    func load(id: UUID) async throws -> Data

    /// サムネイルを読み出す。破棄されていれば原本から作り直す。
    func loadThumbnail(id: UUID) async throws -> Data

    /// 指定した長辺に収まる画像を返す。
    ///
    /// 大きく出す場所ではサムネイル（小さい）では粗く、原本（大きい）では
    /// デコードが重い。必要な大きさだけを渡すための窓口。
    func loadDisplayImage(id: UUID, maxDimension: Int) async throws -> Data

    /// 原本とサムネイルの両方を削除する。存在しなくても失敗させない。
    func delete(id: UUID) async throws
}
