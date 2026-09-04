import Foundation

/// 図鑑表示専用の読み取り。
///
/// 調理回数と最終調理日の集計が要るため Query として実装する。
protocol CookbookQuery: Sendable {
    /// - Parameters:
    ///   - limit: 一度に読む件数。料理は年単位で増え続けるため上限を必須にする。
    ///   - offset: 読み飛ばす件数。ページングに使う。
    func items(sort: CookbookSort, limit: Int, offset: Int) async throws -> [CookbookItem]
}
