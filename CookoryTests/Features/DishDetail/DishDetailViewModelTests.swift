import Foundation
import Testing
@testable import Cookory

@MainActor
struct DishDetailViewModelTests {
    private func make(
        dishes: InMemoryDishRepository = InMemoryDishRepository(),
        meals: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        dishID: UUID
    ) -> DishDetailViewModel {
        {
            let history = GetDishHistoryUseCase(dishRepository: dishes, mealRepository: meals)
            return DishDetailViewModel(
                dishID: dishID,
                getDishHistory: history,
                shareDish: ShareDishUseCase(
                    getDishHistory: history, imageStorage: InMemoryImageStorage()
                )
            )
        }()
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    @Test func 初期状態はloading() {
        #expect(make(dishID: UUID()).state == .loading)
    }

    @Test func 読み込むと履歴が入る() async throws {
        let dishes = InMemoryDishRepository()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()))
        let viewModel = make(dishes: dishes, dishID: dish.id)

        await viewModel.load()

        #expect(viewModel.history?.cookCount == 1)
    }

    @Test func 存在しない料理ではfailedになる() async {
        let viewModel = make(dishID: UUID())

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("failed になっていません")
            return
        }
        #expect(!String(localized: message).contains("DomainError"))
    }

    @Test func お気に入りを切り替えられる() async throws {
        let dishes = InMemoryDishRepository()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        let viewModel = make(dishes: dishes, dishID: dish.id)
        await viewModel.load()

        await viewModel.toggleFavorite()

        #expect(viewModel.history?.dish.isFavorite == true)
    }

    /// お気に入りの切り替えで履歴が消えない。
    @Test func お気に入り切り替えで履歴が保たれる() async throws {
        let dishes = InMemoryDishRepository()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()))
        let viewModel = make(dishes: dishes, dishID: dish.id)
        await viewModel.load()

        await viewModel.toggleFavorite()

        #expect(viewModel.history?.cookCount == 1)
    }

    @Test func 読み込み前のお気に入り操作は何もしない() async throws {
        let dishes = InMemoryDishRepository()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        let viewModel = make(dishes: dishes, dishID: dish.id)

        await viewModel.toggleFavorite()

        #expect(viewModel.state == .loading)
        #expect(try await dishes.find(id: dish.id)?.isFavorite == false)
    }
}
