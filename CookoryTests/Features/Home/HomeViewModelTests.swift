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
        #expect(!message.contains("DomainError"))
    }
}
