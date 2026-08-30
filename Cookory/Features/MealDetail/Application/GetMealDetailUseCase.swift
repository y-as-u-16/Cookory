import Foundation

/// 1 件の食事記録の全体像を取る。
///
/// 記録・写真・紐づく料理をまとめて返す。View が個別に Repository を
/// 叩かないようにするため、ここで組み立てる。
struct GetMealDetailUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository

    init(mealRepository: MealRecordRepository, dishRepository: DishRepository) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
    }

    func execute(id: UUID) async throws -> MealDetail {
        guard let meal = try await mealRepository.find(id: id) else {
            throw DomainError.notFound(id: id)
        }

        var entries: [MealDishEntry] = []
        for log in try await dishRepository.fetchLogs(mealRecordID: id) {
            guard let dish = try await dishRepository.find(id: log.dishID) else { continue }
            entries.append(MealDishEntry(dish: dish, log: log))
        }

        return MealDetail(meal: meal, dishes: entries)
    }
}

/// 食事記録とその中身。
struct MealDetail: Equatable, Sendable {
    let meal: MealRecord
    let dishes: [MealDishEntry]

    var hasDishes: Bool { !dishes.isEmpty }
}

/// 記録に紐づく料理 1 件。料理そのものと、その回の評価・メモを持つ。
struct MealDishEntry: Equatable, Sendable, Identifiable {
    let dish: Dish
    let log: DishLog

    var id: UUID { log.id }
}
