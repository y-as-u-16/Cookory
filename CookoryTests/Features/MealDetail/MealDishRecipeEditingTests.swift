import Foundation
import Testing
@testable import Cookory

/// 記録画面の中で、料理名とレシピを続けて入力できることを確かめる。
@MainActor
struct MealDishRecipeEditingTests {
    private func make(
        mealID: UUID,
        meals: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        dishes: InMemoryDishRepository = InMemoryDishRepository(),
        storage: InMemoryImageStorage = InMemoryImageStorage()
    ) -> MealDetailViewModel {
        MealDetailViewModel(
            mealID: mealID,
            getMealDetail: GetMealDetailUseCase(mealRepository: meals, dishRepository: dishes),
            updateMealRecord: UpdateMealRecordUseCase(mealRepository: meals, dishRepository: dishes),
            assignDishToMeal: AssignDishToMealUseCase(mealRepository: meals, dishRepository: dishes),
            deleteMealRecord: DeleteMealRecordUseCase(
                mealRepository: meals, dishRepository: dishes, imageStorage: storage
            ),
            editRecipe: EditRecipeUseCase(dishRepository: dishes)
        )
    }

    private func seedMeal(
        into meals: InMemoryMealRecordRepository
    ) async throws -> MealRecord {
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)
        return meal
    }

    @Test func 料理を追加すると編集欄が開く() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()

        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)
        #expect(viewModel.expandedDishID == dishID)
    }

    @Test func 追加した料理にそのままレシピを書ける() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)

        viewModel.recipeDraft(for: dishID).ingredients = "鶏もも肉 300g"
        viewModel.recipeDraft(for: dishID).steps = "1. 下味をつける"
        await viewModel.saveRecipe(dishID: dishID)

        let saved = try #require(try await dishes.findRecipe(dishID: dishID))
        #expect(saved.ingredients == "鶏もも肉 300g")
        #expect(saved.steps == "1. 下味をつける")
    }

    @Test func 既存レシピは展開時に読み込まれる() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = try await seedMeal(into: meals)
        let dish = Dish(name: try #require(DishName("肉じゃが")))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: Date())
        )
        try await dishes.save(
            Recipe(dishID: dish.id, ingredients: "じゃがいも 3個", steps: "1. 煮る")
        )
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        await viewModel.toggleExpansion(dishID: dish.id)

        #expect(viewModel.recipeDraft(for: dish.id).ingredients == "じゃがいも 3個")
        #expect(viewModel.recipeDraft(for: dish.id).steps == "1. 煮る")
    }

    /// 別の料理を開いても、書きかけの内容は失われない。
    @Test func 書きかけは折りたたんでも残る() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)

        viewModel.recipeDraft(for: dishID).steps = "書きかけ"
        await viewModel.toggleExpansion(dishID: dishID)
        await viewModel.toggleExpansion(dishID: dishID)

        #expect(viewModel.recipeDraft(for: dishID).steps == "書きかけ")
    }

    @Test func リンクを追加できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)

        viewModel.recipeDraft(for: dishID).linkURL = "https://example.com/karaage"
        viewModel.recipeDraft(for: dishID).linkTitle = "参考動画"
        await viewModel.addLink(dishID: dishID)

        #expect(viewModel.recipeDraft(for: dishID).links.count == 1)
        #expect(viewModel.recipeDraft(for: dishID).links.first?.displayName == "参考動画")
        #expect(viewModel.recipeDraft(for: dishID).linkURL.isEmpty)
    }

    @Test func 不正なリンクは弾かれる() async throws {
        let meals = InMemoryMealRecordRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)

        viewModel.recipeDraft(for: dishID).linkURL = "javascript:alert(1)"

        #expect(!viewModel.canAddLink(dishID: dishID))
        await viewModel.addLink(dishID: dishID)
        #expect(viewModel.recipeDraft(for: dishID).links.isEmpty)
    }

    @Test func リンクを削除できる() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)
        viewModel.recipeDraft(for: dishID).linkURL = "https://example.com/karaage"
        await viewModel.addLink(dishID: dishID)
        let linkID = try #require(viewModel.recipeDraft(for: dishID).links.first?.id)

        await viewModel.removeLink(dishID: dishID, linkID: linkID)

        #expect(viewModel.recipeDraft(for: dishID).links.isEmpty)
    }

    /// 材料も手順もリンクも空なら、レシピは作らない。
    @Test func 空のレシピは保存されない() async throws {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let meal = try await seedMeal(into: meals)
        let viewModel = make(mealID: meal.id, meals: meals, dishes: dishes)
        await viewModel.load()

        viewModel.dishNameDraft = "唐揚げ"
        await viewModel.addDish()
        let dishID = try #require(viewModel.detail?.dishes.first?.dish.id)

        await viewModel.saveRecipe(dishID: dishID)

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
    }
}

/// 書きかけを守る仕組みが、他の画面で保存された内容を握り潰さないことを確かめる。
@MainActor
struct DishRecipeDraftTests {
    @Test func 未編集の欄は最新の保存内容に追従する() throws {
        let dishID = UUID()
        let draft = DishRecipeDraft()
        draft.apply(Recipe(dishID: dishID, ingredients: "旧", steps: "旧手順"))

        // 別画面で書き換えられた状態。
        draft.apply(Recipe(dishID: dishID, ingredients: "新", steps: "新手順"))

        #expect(draft.ingredients == "新")
        #expect(draft.steps == "新手順")
    }

    @Test func 編集した欄は最新の保存内容で上書きされない() throws {
        let dishID = UUID()
        let draft = DishRecipeDraft()
        draft.apply(Recipe(dishID: dishID, ingredients: "旧", steps: "旧手順"))

        draft.ingredients = "書きかけ"
        draft.apply(Recipe(dishID: dishID, ingredients: "新", steps: "新手順"))

        #expect(draft.ingredients == "書きかけ")
        // 触っていない欄は追従してよい。
        #expect(draft.steps == "新手順")
    }

    @Test func リンクは常に最新になる() throws {
        let dishID = UUID()
        let draft = DishRecipeDraft()
        draft.apply(Recipe(dishID: dishID))
        let link = try #require(RecipeLink(rawURL: "https://example.com"))

        draft.apply(Recipe(dishID: dishID, links: [link]))

        #expect(draft.links == [link])
    }
}
