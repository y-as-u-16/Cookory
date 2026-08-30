import Foundation
import Testing
@testable import Cookory

@MainActor
struct CookbookViewModelTests {
    private func item(_ name: String, count: Int = 1) throws -> CookbookItem {
        CookbookItem(
            dish: Dish(name: try #require(DishName(name))),
            cookCount: count,
            lastCookedAt: Date(),
            latestPhotoID: nil
        )
    }

    @Test func 読み込むと一覧が入る() async throws {
        let query = StubCookbookQuery(items: [try item("唐揚げ"), try item("カレー")])
        let viewModel = CookbookViewModel(query: query)

        await viewModel.load()

        #expect(viewModel.items.count == 2)
    }

    @Test func 料理が無ければ空状態になる() async {
        let viewModel = CookbookViewModel(query: StubCookbookQuery())

        await viewModel.load()

        #expect(viewModel.isEmpty)
    }

    @Test func ソートを変えると並びが変わる() async throws {
        let query = StubCookbookQuery(items: [
            try item("Z", count: 1), try item("A", count: 5),
        ])
        let viewModel = CookbookViewModel(query: query)
        await viewModel.load()

        await viewModel.changeSort(to: .mostCooked)

        #expect(viewModel.items.map(\.dish.name.value) == ["A", "Z"])
        #expect(viewModel.sort == .mostCooked)
    }

    /// 同じソートを選び直したときに読み直さない。
    @Test func 同じソートなら何もしない() async throws {
        let query = StubCookbookQuery(items: [try item("唐揚げ")])
        let viewModel = CookbookViewModel(query: query)
        await viewModel.load()

        await viewModel.changeSort(to: viewModel.sort)

        #expect(viewModel.items.count == 1)
    }

    @Test func 満杯でなければ続きは無いと判断する() async throws {
        let query = StubCookbookQuery(items: [try item("唐揚げ")])
        let viewModel = CookbookViewModel(query: query)

        await viewModel.load()

        #expect(!viewModel.hasMore)
    }

    @Test func 満杯なら続きを読む() async throws {
        let items = try (0..<CookbookViewModel.pageSize + 10).map { try item("料理\($0)") }
        let query = StubCookbookQuery(items: items)
        let viewModel = CookbookViewModel(query: query)
        await viewModel.load()
        #expect(viewModel.hasMore)

        await viewModel.loadMore()

        #expect(viewModel.items.count == items.count)
        #expect(!viewModel.hasMore)
    }

    /// 続きが無いのに読みに行くと同じ行が二重に並ぶ。
    @Test func 続きが無ければloadMoreは何もしない() async throws {
        let query = StubCookbookQuery(items: [try item("唐揚げ")])
        let viewModel = CookbookViewModel(query: query)
        await viewModel.load()

        await viewModel.loadMore()

        #expect(viewModel.items.count == 1)
    }

    @Test func 読み込みに失敗するとメッセージが入る() async {
        let query = StubCookbookQuery()
        await query.setError(.persistenceFailed)
        let viewModel = CookbookViewModel(query: query)

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("DomainError") == false)
    }
}
