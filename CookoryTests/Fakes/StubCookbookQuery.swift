import Foundation
@testable import Cookory

/// テスト用の CookbookQuery。ソートとページングは実装と同じ関数を使う。
actor StubCookbookQuery: CookbookQuery {
    private var allItems: [CookbookItem]
    private var errorToThrow: DomainError?

    init(items: [CookbookItem] = []) {
        allItems = items
    }

    func items(sort: CookbookSort, limit: Int, offset: Int) async throws -> [CookbookItem] {
        if let errorToThrow { throw errorToThrow }
        return SwiftDataCookbookQuery.sorted(allItems, by: sort)
            .dropFirst(offset)
            .prefix(limit)
            .map { $0 }
    }

    func setItems(_ items: [CookbookItem]) {
        allItems = items
    }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }
}
