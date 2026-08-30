import Foundation
import SwiftData

/// MealRecordRepository の SwiftData 実装。
///
/// SwiftData の例外はここで DomainError に翻訳する。上位層に永続化の都合を出さない。
struct SwiftDataMealRecordRepository: MealRecordRepository {
    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    func find(id: UUID) async throws -> MealRecord? {
        try await withPersistenceError {
            try await store.fetchOne(FetchDescriptor<MealRecordModel>(
                predicate: #Predicate { $0.id == id }
            ))?.toDomain()
        }
    }

    func fetchRecent(limit: Int) async throws -> [MealRecord] {
        guard limit > 0 else { return [] }
        return try await withPersistenceError {
            var descriptor = FetchDescriptor<MealRecordModel>(
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            return try await store.fetch(descriptor).map { $0.toDomain() }
        }
    }

    func fetchPage(offset: Int, limit: Int) async throws -> [MealRecord] {
        guard limit > 0 else { return [] }
        return try await withPersistenceError {
            var descriptor = FetchDescriptor<MealRecordModel>(
                sortBy: [SortDescriptor(\.occurredAt)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            return try await store.fetch(descriptor).map { $0.toDomain() }
        }
    }

    func save(_ meal: MealRecord) async throws {
        try await withPersistenceError {
            let id = meal.id
            let existing = try await store.fetchOne(FetchDescriptor<MealRecordModel>(
                predicate: #Predicate { $0.id == id }
            ))
            if let existing {
                existing.update(from: meal)
            } else {
                await store.insert(MealRecordModel(from: meal))
            }
            try await store.save()
        }
    }

    func delete(id: UUID) async throws {
        try await withPersistenceError {
            guard let model = try await store.fetchOne(FetchDescriptor<MealRecordModel>(
                predicate: #Predicate { $0.id == id }
            )) else { return }
            await store.delete(model)
            try await store.save()
        }
    }
}
