import Foundation
import Testing
@testable import Cookory

@MainActor
struct MealDetailViewModelTests {
    private func make(
        mealID: UUID,
        meals: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        dishes: InMemoryDishRepository = InMemoryDishRepository(),
        storage: InMemoryImageStorage = InMemoryImageStorage()
    ) -> MealDetailViewModel {
        MealDetailViewModel(
            mealID: mealID,
            getMealDetail: GetMealDetailUseCase(
                mealRepository: meals, dishRepository: dishes
            ),
            updateMealRecord: UpdateMealRecordUseCase(
                mealRepository: meals, dishRepository: dishes
            ),
            assignDishToMeal: AssignDishToMealUseCase(
                mealRepository: meals, dishRepository: dishes
            ),
            deleteMealRecord: DeleteMealRecordUseCase(
                mealRepository: meals, dishRepository: dishes, imageStorage: storage
            ),
            editRecipe: EditRecipeUseCase(dishRepository: dishes)
        )
    }

    @Test func 記録を読み込める() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date(), mealType: .dinner, note: "美味しかった")
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)

        await viewModel.load()

        #expect(viewModel.detail?.meal.id == meal.id)
        #expect(viewModel.noteDraft == "美味しかった")
        #expect(viewModel.mealTypeDraft == .dinner)
    }

    @Test func 存在しない記録ではfailedになる() async {
        let viewModel = make(mealID: UUID())

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("failed になっていません")
            return
        }
        #expect(!String(localized: message).contains("DomainError"))
    }

    @Test func メモを保存できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.noteDraft = "塩を控えめに"
        viewModel.mealTypeDraft = .lunch
        await viewModel.saveMeal()

        let saved = try await meals.find(id: meal.id)
        #expect(saved?.note == "塩を控えめに")
        #expect(saved?.mealType == .lunch)
    }

    @Test func 料理名を追加できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()

        #expect(viewModel.detail?.dishes.count == 1)
        #expect(viewModel.detail?.dishes.first?.dish.name.value == "唐揚げ")
    }

    /// 追加後に入力欄を空にする。同じ名前を二度追加しないため。
    @Test func 追加すると入力欄が空になる() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()

        #expect(viewModel.dishNameDraft.isEmpty)
    }

    @Test func 空の料理名は追加できない() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.dishNameDraft = "   "

        #expect(!viewModel.canAddDish)
        await viewModel.addDish()
        #expect(viewModel.detail?.dishes.isEmpty == true)
    }

    @Test func 記録を削除できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        let deleted = await viewModel.deleteMeal()

        #expect(deleted)
        #expect(try await meals.find(id: meal.id) == nil)
    }

    /// 読み込みのたびに書きかけを消さない。
    @Test func 書きかけのメモは再読み込みで消えない() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = MealRecord(occurredAt: Date(), note: "元のメモ")
        try await meals.save(meal)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.noteDraft = "書きかけ"
        await viewModel.load()

        #expect(viewModel.noteDraft == "書きかけ")
    }
}

struct GetMealDetailUseCaseTests {
    private func make() -> (GetMealDetailUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (GetMealDetailUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes)
    }

    @Test func 記録と料理をまとめて返す() async throws {
        let (useCase, meals, dishes) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        let dish = Dish(name: try #require(DishName("唐揚げ")))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, rating: DishRating(5), cookedAt: Date())
        )

        let detail = try await useCase.execute(id: meal.id)

        #expect(detail.hasDishes)
        #expect(detail.dishes.first?.dish.name.value == "唐揚げ")
        #expect(detail.dishes.first?.log.rating == DishRating(5))
    }

    @Test func 料理が無くても成立する() async throws {
        let (useCase, meals, _) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        let detail = try await useCase.execute(id: meal.id)

        #expect(!detail.hasDishes)
    }

    @Test func 他の記録の料理は混ざらない() async throws {
        let (useCase, meals, dishes) = make()
        let target = MealRecord(occurredAt: Date())
        let other = MealRecord(occurredAt: Date())
        try await meals.save(target)
        try await meals.save(other)
        let dish = Dish(name: try #require(DishName("唐揚げ")))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: other.id, cookedAt: Date())
        )

        #expect(try await useCase.execute(id: target.id).dishes.isEmpty)
    }

    @Test func 存在しない記録は失敗する() async throws {
        let (useCase, _, _) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.execute(id: missingID)
        }
    }
}
