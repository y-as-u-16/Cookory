import Foundation
import Testing
@testable import Cookory

struct UpdateMealRecordUseCaseTests {
    private func make() -> (UpdateMealRecordUseCase, InMemoryMealRecordRepository, InMemoryDishRepository) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        return (UpdateMealRecordUseCase(mealRepository: meals, dishRepository: dishes), meals, dishes)
    }

    @Test func 食事の種類とメモを書き換えられる() async throws {
        let (useCase, meals, _) = make()
        let meal = MealRecord(occurredAt: Date())
        try await meals.save(meal)

        let updated = try await useCase.updateMeal(id: meal.id, mealType: .dinner, note: "満足")

        #expect(updated.mealType == .dinner)
        #expect(updated.note == "満足")
        #expect(try await meals.find(id: meal.id)?.note == "満足")
    }

    @Test func メモを空にできる() async throws {
        let (useCase, meals, _) = make()
        let meal = MealRecord(occurredAt: Date(), note: "元のメモ")
        try await meals.save(meal)

        let updated = try await useCase.updateMeal(id: meal.id, mealType: nil, note: nil)

        #expect(updated.note == nil)
    }

    @Test func 存在しない記録の更新は失敗する() async throws {
        let (useCase, _, _) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.updateMeal(id: missingID, mealType: .lunch, note: nil)
        }
    }

    @Test func 調理履歴の評価とメモを書き換えられる() async throws {
        let (useCase, _, dishes) = make()
        let mealRecordID = UUID()
        let log = DishLog(dishID: UUID(), mealRecordID: mealRecordID, cookedAt: Date())
        try await dishes.save(log)

        let updated = try await useCase.updateLog(
            id: log.id, mealRecordID: mealRecordID, rating: DishRating(4), note: "次は薄味で"
        )

        #expect(updated.rating == DishRating(4))
        #expect(updated.note == "次は薄味で")
    }

    @Test func 評価を取り消せる() async throws {
        let (useCase, _, dishes) = make()
        let mealRecordID = UUID()
        let log = DishLog(
            dishID: UUID(), mealRecordID: mealRecordID, rating: DishRating(3), cookedAt: Date()
        )
        try await dishes.save(log)

        let updated = try await useCase.updateLog(
            id: log.id, mealRecordID: mealRecordID, rating: nil, note: nil
        )

        #expect(updated.rating == nil)
    }

    @Test func 存在しない履歴の更新は失敗する() async throws {
        let (useCase, _, _) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.updateLog(
                id: missingID, mealRecordID: UUID(), rating: nil, note: nil
            )
        }
    }
}
