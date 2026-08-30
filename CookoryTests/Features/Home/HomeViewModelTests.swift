import Foundation
import Testing
@testable import Cookory

@MainActor
struct HomeViewModelTests {
    private func make(
        meals: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        dishes: InMemoryDishRepository = InMemoryDishRepository()
    ) -> HomeViewModel {
        HomeViewModel(
            getHomeContent: GetHomeContentUseCase(mealRepository: meals, dishRepository: dishes)
        )
    }

    @Test func 初期状態はloading() {
        #expect(make().state == .loading)
    }

    @Test func 読み込みに成功するとloadedになる() async {
        let viewModel = make()

        await viewModel.load()

        #expect(viewModel.content != nil)
    }

    @Test func 記録が0件なら空状態になる() async {
        let viewModel = make()

        await viewModel.load()

        #expect(viewModel.isEmpty)
    }

    @Test func 記録があれば空状態にならない() async throws {
        let meals = InMemoryMealRecordRepository()
        try await meals.save(MealRecord(occurredAt: Date()))
        let viewModel = make(meals: meals)

        await viewModel.load()

        #expect(!viewModel.isEmpty)
        #expect(viewModel.content?.recentMeals.count == 1)
    }

    @Test func 読み込みに失敗するとfailedになる() async {
        let meals = InMemoryMealRecordRepository()
        await meals.setError(.persistenceFailed)
        let viewModel = make(meals: meals)

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("failed になっていません")
            return
        }
        #expect(!String(localized: message).contains("DomainError"))
    }
}

/// エラー文言が英語設定で英語になること。
///
/// 以前は ViewModel に日本語を直書きしていたため、英語設定でも
/// 日本語のエラーが出ていた。
@MainActor
struct ErrorMessageLocalizationTests {
    @Test func エラー文言が言語設定に追従する() async {
        let meals = InMemoryMealRecordRepository()
        await meals.setError(.persistenceFailed)
        let viewModel = HomeViewModel(
            getHomeContent: GetHomeContentUseCase(
                mealRepository: meals, dishRepository: InMemoryDishRepository()
            )
        )

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("failed になっていません")
            return
        }

        var japanese = message
        japanese.locale = Locale(identifier: "ja_JP")
        var english = message
        english.locale = Locale(identifier: "en_US")

        #expect(String(localized: japanese) != String(localized: english))
        #expect(!String(localized: english).contains("ませ"))
    }

    /// 内部表現を利用者に見せない。
    @Test func どの言語でも内部表現が出ない() async {
        let meals = InMemoryMealRecordRepository()
        await meals.setError(.persistenceFailed)
        let viewModel = HomeViewModel(
            getHomeContent: GetHomeContentUseCase(
                mealRepository: meals, dishRepository: InMemoryDishRepository()
            )
        )
        await viewModel.load()

        guard case .failed(let message) = viewModel.state else { return }

        for identifier in ["ja_JP", "en_US"] {
            var localized = message
            localized.locale = Locale(identifier: identifier)
            let text = String(localized: localized)
            #expect(!text.contains("DomainError"))
            #expect(!text.contains("persistenceFailed"))
        }
    }
}
