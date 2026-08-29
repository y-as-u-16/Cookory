import Foundation

/// 食事記録に料理を紐づける。Dish と DishLog が生まれる唯一の入口。
struct AssignDishToMealUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    /// - Returns: 作成された調理履歴。
    /// - Throws: 対象の食事記録が無ければ ``DomainError/notFound(id:)``。
    @discardableResult
    func execute(
        mealRecordID: UUID,
        dishName: DishName,
        rating: DishRating? = nil,
        note: String? = nil,
        now: Date = Date()
    ) async throws -> DishLog {
        guard let meal = try await mealRepository.find(id: mealRecordID) else {
            throw DomainError.notFound(id: mealRecordID)
        }

        // 同じ料理名なら既存の Dish を引く。ここで新規作成すると
        // Cookbook に「唐揚げ」が何件も並び、アプリの中核価値が壊れる。
        let dish: Dish
        if let existing = try await dishRepository.find(name: dishName) {
            dish = existing
        } else {
            dish = Dish(name: dishName, createdAt: now)
            try await dishRepository.save(dish)
        }

        let log = DishLog(
            dishID: dish.id,
            mealRecordID: mealRecordID,
            rating: rating,
            note: note,
            cookedAt: meal.occurredAt
        )
        try await dishRepository.save(log)
        try await mealRepository.save(meal.addingDishLog(log.id, at: now))

        return log
    }
}
