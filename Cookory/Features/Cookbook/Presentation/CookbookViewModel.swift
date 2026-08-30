import Foundation
import Observation

@MainActor
@Observable
final class CookbookViewModel {
    /// 1 度に読む件数。料理は年単位で増え続けるため全件を載せない。
    static let pageSize = 50

    private(set) var items: [CookbookItem] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    private(set) var errorMessage: LocalizedStringResource?

    var sort: CookbookSort = .recentlyCooked

    private let query: CookbookQuery

    init(query: CookbookQuery) {
        self.query = query
    }

    var isEmpty: Bool { items.isEmpty && !isLoading && errorMessage == nil }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await query.items(sort: sort, limit: Self.pageSize, offset: 0)
            hasMore = items.count == Self.pageSize
            errorMessage = nil
        } catch {
            items = []
            errorMessage = L10n.errorLoad
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let next = try await query.items(
                sort: sort, limit: Self.pageSize, offset: items.count
            )
            items.append(contentsOf: next)
            hasMore = next.count == Self.pageSize
        } catch {
            errorMessage = L10n.errorLoad
        }
    }

    func changeSort(to newSort: CookbookSort) async {
        guard newSort != sort else { return }
        sort = newSort
        await load()
    }
}
