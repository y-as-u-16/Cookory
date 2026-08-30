import Foundation
@testable import Cookory

/// テスト用の SearchQuery。呼ばれた回数を数えてデバウンスを検証する。
actor StubSearchQuery: SearchQuery {
    private var results: SearchResults
    private var errorToThrow: DomainError?
    private(set) var callCount = 0
    private(set) var lastKeyword: String?

    init(results: SearchResults = .empty) {
        self.results = results
    }

    func search(keyword: String, limit: Int) async throws -> SearchResults {
        callCount += 1
        lastKeyword = keyword
        if let errorToThrow { throw errorToThrow }
        return results
    }

    func setResults(_ newResults: SearchResults) {
        results = newResults
    }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }
}
