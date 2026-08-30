import Foundation
import Testing
@testable import Cookory

@MainActor
struct SearchViewModelTests {
    private func item(_ name: String) throws -> CookbookItem {
        CookbookItem(
            dish: Dish(name: try #require(DishName(name))),
            cookCount: 1, lastCookedAt: Date(), latestPhotoID: nil
        )
    }

    /// デバウンスを事実上無効にして即座に検索させる。
    private let noDebounce: Duration = .milliseconds(1)

    @Test func 検索すると結果が入る() async throws {
        let query = StubSearchQuery(results: SearchResults(dishes: [try item("唐揚げ")], meals: []))
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "唐揚げ"

        await viewModel.search()

        #expect(viewModel.results.dishes.count == 1)
    }

    @Test func 空文字なら検索しない() async {
        let query = StubSearchQuery()
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "   "

        await viewModel.search()

        #expect(await query.callCount == 0)
    }

    @Test func 前後の空白は除いて検索する() async {
        let query = StubSearchQuery()
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "  唐揚げ  "

        await viewModel.search()

        #expect(await query.lastKeyword == "唐揚げ")
    }

    @Test func 該当なしの状態が分かる() async {
        let viewModel = SearchViewModel(query: StubSearchQuery(), debounce: noDebounce)
        viewModel.keyword = "存在しない"

        await viewModel.search()

        #expect(viewModel.hasNoMatch)
    }

    /// 入力が空のときは「該当なし」ではない。案内の出し分けに使う。
    @Test func 入力が空なら該当なしにはならない() {
        let viewModel = SearchViewModel(query: StubSearchQuery(), debounce: noDebounce)

        #expect(!viewModel.hasNoMatch)
    }

    @Test func クリアで結果が消える() async throws {
        let query = StubSearchQuery(results: SearchResults(dishes: [try item("唐揚げ")], meals: []))
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "唐揚げ"
        await viewModel.search()

        viewModel.clear()

        #expect(viewModel.keyword.isEmpty)
        #expect(viewModel.results.isEmpty)
    }

    @Test func 入力を空にすると結果が消える() async throws {
        let query = StubSearchQuery(results: SearchResults(dishes: [try item("唐揚げ")], meals: []))
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "唐揚げ"
        await viewModel.search()

        viewModel.keywordChanged(to: "")

        #expect(viewModel.results.isEmpty)
    }

    /// タイプするたびにクエリを投げると件数が増えたとき重くなる。
    /// デバウンスを十分長く取り、待たずに検証する。実時間に依存させると
    /// 遅いマシンで途中の入力が発火し、偽陽性で落ちる。
    @Test func 連続入力では途中の入力で検索しない() async {
        let query = StubSearchQuery()
        let viewModel = SearchViewModel(query: query, debounce: .seconds(30))

        viewModel.keywordChanged(to: "か")
        viewModel.keywordChanged(to: "から")
        viewModel.keywordChanged(to: "からあげ")

        #expect(await query.callCount == 0)
    }

    /// 入力が落ち着けば最後の語で 1 度だけ検索する。
    @Test func 入力が落ち着くと最後の語で検索する() async {
        let query = StubSearchQuery()
        let viewModel = SearchViewModel(query: query, debounce: .milliseconds(1))

        viewModel.keywordChanged(to: "か")
        viewModel.keywordChanged(to: "から")
        viewModel.keywordChanged(to: "からあげ")

        // 固定時間の待機にすると遅いマシンで足りなくなる。発火するまで待つ。
        for _ in 0..<100 where await query.callCount == 0 {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(await query.callCount == 1)
        #expect(await query.lastKeyword == "からあげ")
    }

    @Test func 検索に失敗するとメッセージが入る() async {
        let query = StubSearchQuery()
        await query.setError(.persistenceFailed)
        let viewModel = SearchViewModel(query: query, debounce: noDebounce)
        viewModel.keyword = "唐揚げ"

        await viewModel.search()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("DomainError") == false)
    }
}
