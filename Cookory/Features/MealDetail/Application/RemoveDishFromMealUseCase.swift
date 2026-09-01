import Foundation

/// 食事記録から料理の紐づけを外す。
///
/// Dish 自体は消さない。打ち間違えて付けた料理を外すだけで、
/// 「唐揚げを作れる」という事実まで消えるのは利用者の意図と異なる。
struct RemoveDishFromMealUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    /// 存在しない組み合わせを渡しても失敗させない。削除の再実行を安全にするため。
    func execute(mealRecordID: UUID, dishLogID: UUID, now: Date = Date()) async throws {
        guard let meal = try await mealRepository.find(id: mealRecordID) else { return }

        try await dishRepository.deleteLog(id: dishLogID)
        try await mealRepository.save(meal.removingDishLog(dishLogID, at: now))
    }
}
