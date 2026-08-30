import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    /// 入力が落ち着くまで待つ時間。タイプするたびにクエリを投げると
    /// 件数が増えたとき重くなる。
    static let debounceInterval: Duration = .milliseconds(300)
    static let resultLimit = 50

    private(set) var results: SearchResults = .empty
    private(set) var isSearching = false
    private(set) var errorMessage: LocalizedStringResource?

    var keyword: String = ""

    private let query: SearchQuery
    private let debounce: Duration
    private var searchTask: Task<Void, Never>?

    init(query: SearchQuery, debounce: Duration = SearchViewModel.debounceInterval) {
        self.query = query
        self.debounce = debounce
    }

    /// 入力が空でないのに結果が無い状態。案内を出し分けるために使う。
    var hasNoMatch: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && results.isEmpty && !isSearching && errorMessage == nil
    }

    /// 入力の変化を受けてデバウンス付きで検索する。
    func keywordChanged(to newKeyword: String) {
        keyword = newKeyword
        searchTask?.cancel()

        guard !newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = .empty
            errorMessage = nil
            return
        }

        searchTask = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    /// デバウンスを挟まず即座に検索する。
    func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = .empty
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await query.search(keyword: trimmed, limit: Self.resultLimit)
            errorMessage = nil
        } catch {
            results = .empty
            errorMessage = L10n.errorGeneric
        }
    }

    func clear() {
        searchTask?.cancel()
        keyword = ""
        results = .empty
        errorMessage = nil
    }
}
