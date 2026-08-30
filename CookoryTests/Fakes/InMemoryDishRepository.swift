import Foundation
@testable import Cookory

/// テスト用の DishRepository。
actor InMemoryDishRepository: DishRepository {
    private var dishes: [UUID: Dish] = [:]
    private var logs: [UUID: DishLog] = [:]

    var errorToThrow: DomainError?

    init(dishes seedDishes: [Dish] = [], logs seedLogs: [DishLog] = []) {
        for dish in seedDishes {
            dishes[dish.id] = dish
        }
        for log in seedLogs {
            logs[log.id] = log
        }
    }

    func find(id: UUID) async throws -> Dish? {
        try throwIfNeeded()
        return dishes[id]
    }

    func fetchAll() async throws -> [Dish] {
        try throwIfNeeded()
        return dishes.values.sorted { $0.name.value < $1.name.value }
    }

    func find(name: DishName) async throws -> Dish? {
        try throwIfNeeded()
        return dishes.values.first { $0.name == name }
    }

    func save(_ dish: Dish) async throws {
        try throwIfNeeded()
        dishes[dish.id] = dish
    }

    func delete(id: UUID) async throws {
        try throwIfNeeded()
        dishes.removeValue(forKey: id)
        logs = logs.filter { $0.value.dishID != id }
    }

    func fetchLogs(dishID: UUID) async throws -> [DishLog] {
        try throwIfNeeded()
        return logs.values
            .filter { $0.dishID == dishID }
            .sorted { $0.cookedAt > $1.cookedAt }
    }

    func fetchLogs(mealRecordID: UUID) async throws -> [DishLog] {
        try throwIfNeeded()
        return logs.values
            .filter { $0.mealRecordID == mealRecordID }
            .sorted { $0.cookedAt > $1.cookedAt }
    }

    func save(_ log: DishLog) async throws {
        try throwIfNeeded()
        logs[log.id] = log
    }

    func deleteLog(id: UUID) async throws {
        try throwIfNeeded()
        logs.removeValue(forKey: id)
    }

    // MARK: - Test helpers

    var dishCount: Int { dishes.count }
    var logCount: Int { logs.count }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }

    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
