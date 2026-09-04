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
            try await store.perform { context in
                try context.fetchOne(FetchDescriptor<MealRecordModel>(
                    predicate: #Predicate { $0.id == id }
                ))?.toDomain()
            }
        }
    }

    func find(ids: [UUID]) async throws -> [UUID: MealRecord] {
        guard !ids.isEmpty else { return [:] }
        let unique = Set(ids)
        return try await withPersistenceError {
            try await store.perform { context in
                let models = try context.fetch(FetchDescriptor<MealRecordModel>(
                    predicate: #Predicate { unique.contains($0.id) }
                ))
                return Dictionary(
                    models.map { ($0.id, $0.toDomain()) }, uniquingKeysWith: { first, _ in first }
                )
            }
        }
    }

    func fetchRecent(limit: Int) async throws -> [MealRecord] {
        guard limit > 0 else { return [] }
        return try await withPersistenceError {
            try await store.perform { context in
                var descriptor = FetchDescriptor<MealRecordModel>(
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                )
                descriptor.fetchLimit = limit
                return try context.fetch(descriptor).map { $0.toDomain() }
            }
        }
    }

    func fetchPage(offset: Int, limit: Int) async throws -> [MealRecord] {
        guard limit > 0 else { return [] }
        return try await withPersistenceError {
            try await store.perform { context in
                var descriptor = FetchDescriptor<MealRecordModel>(
                    sortBy: [SortDescriptor(\.occurredAt)]
                )
                descriptor.fetchOffset = offset
                descriptor.fetchLimit = limit
                return try context.fetch(descriptor).map { $0.toDomain() }
            }
        }
    }

    func save(_ meal: MealRecord) async throws {
        try await withPersistenceError {
            let id = meal.id
            try await store.performAndSave { context in
                let existing = try context.fetchOne(FetchDescriptor<MealRecordModel>(
                    predicate: #Predicate { $0.id == id }
                ))
                if let existing {
                    existing.update(from: meal)
                } else {
                    context.insert(MealRecordModel(from: meal))
                }
            }
        }
    }

    func delete(id: UUID) async throws {
        try await withPersistenceError {
            try await store.performAndSave { context in
                guard let model = try context.fetchOne(FetchDescriptor<MealRecordModel>(
                    predicate: #Predicate { $0.id == id }
                )) else { return }
                context.delete(model)
            }
        }
    }
}
