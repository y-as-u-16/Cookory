import Foundation

/// 料理名とメモを対象にした検索。
///
/// MVP は部分一致で始める。ひらがな・カタカナの揺れ吸収は、
/// 実際に使って不足を確認してから拡張する。
protocol SearchQuery: Sendable {
    /// - Parameter limit: 件数上限。結果が多いときに全件を載せない。
    func search(keyword: String, limit: Int) async throws -> SearchResults
}

/// 検索結果。料理とメモは別のまとまりとして返す。
struct SearchResults: Equatable, Sendable {
    var dishes: [CookbookItem]
    var meals: [MealRecord]

    var isEmpty: Bool { dishes.isEmpty && meals.isEmpty }

    static let empty = SearchResults(dishes: [], meals: [])
}
