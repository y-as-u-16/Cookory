import Foundation
@testable import Cookory

/// テスト用の MealRecordRepository。
///
/// actor にしているのは protocol が Sendable を要求するため。
/// 実装の SwiftDataStore も @ModelActor で直列化されるので、性質を揃えている。
actor InMemoryMealRecordRepository: MealRecordRepository {
    private var storage: [UUID: MealRecord] = [:]

    /// 次の操作で投げるエラー。異常系のテストで注入する。
    var errorToThrow: DomainError?

    init(seed: [MealRecord] = []) {
        for record in seed {
            storage[record.id] = record
        }
    }

    func find(id: UUID) async throws -> MealRecord? {
        try throwIfNeeded()
        return storage[id]
    }

    func fetchRecent(limit: Int) async throws -> [MealRecord] {
        try throwIfNeeded()
        return storage.values
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(limit)
            .map { $0 }
    }

    func fetchPage(offset: Int, limit: Int) async throws -> [MealRecord] {
        try throwIfNeeded()
        guard limit > 0 else { return [] }
        return storage.values
            .sorted { $0.occurredAt < $1.occurredAt }
            .dropFirst(offset)
            .prefix(limit)
            .map { $0 }
    }

    func save(_ meal: MealRecord) async throws {
        try throwIfNeeded()
        storage[meal.id] = meal
    }

    func delete(id: UUID) async throws {
        try throwIfNeeded()
        storage.removeValue(forKey: id)
    }

    // MARK: - Test helpers

    var count: Int { storage.count }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }

    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
