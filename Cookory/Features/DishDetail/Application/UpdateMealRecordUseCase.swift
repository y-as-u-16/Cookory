import Foundation

/// 記録済みの内容を書き換える。
struct UpdateMealRecordUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    /// 食事の種類とメモを書き換える。
    @discardableResult
    func updateMeal(
        id: UUID,
        mealType: MealType?,
        note: String?,
        now: Date = Date()
    ) async throws -> MealRecord {
        guard let meal = try await mealRepository.find(id: id) else {
            throw DomainError.notFound(id: id)
        }
        let updated = meal.edited(mealType: mealType, note: note, at: now)
        try await mealRepository.save(updated)
        return updated
    }

    /// 料理の名前を変える。図鑑や過去の記録に出る名前もまとめて変わる。
    ///
    /// 同じ名前の料理が既にあるときは弾く。統合すると、統合前の履歴を
    /// 元に戻せなくなる。
    @discardableResult
    func renameDish(id: UUID, to newName: DishName, now: Date = Date()) async throws -> Dish {
        guard let dish = try await dishRepository.find(id: id) else {
            throw DomainError.notFound(id: id)
        }
        guard dish.name != newName else { return dish }

        if let existing = try await dishRepository.find(name: newName), existing.id != id {
            throw DomainError.invalidInput(reason: "同じ名前の料理があります")
        }

        let updated = dish.renamed(to: newName, at: now)
        try await dishRepository.save(updated)
        return updated
    }

    /// 調理履歴の評価とメモを書き換える。
    @discardableResult
    func updateLog(
        id: UUID,
        mealRecordID: UUID,
        rating: DishRating?,
        note: String?
    ) async throws -> DishLog {
        let logs = try await dishRepository.fetchLogs(mealRecordID: mealRecordID)
        guard let log = logs.first(where: { $0.id == id }) else {
            throw DomainError.notFound(id: id)
        }
        let updated = log.rated(rating).noted(note)
        try await dishRepository.save(updated)
        return updated
    }
}
