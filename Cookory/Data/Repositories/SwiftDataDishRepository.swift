import Foundation
import SwiftData

/// DishRepository の SwiftData 実装。
struct SwiftDataDishRepository: DishRepository {
    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    func find(id: UUID) async throws -> Dish? {
        try await withPersistenceError {
            try await store.fetchOne(FetchDescriptor<DishModel>(
                predicate: #Predicate { $0.id == id }
            ))?.toDomain()
        }
    }

    func fetchAll() async throws -> [Dish] {
        try await withPersistenceError {
            try await store.fetch(FetchDescriptor<DishModel>(
                sortBy: [SortDescriptor(\.name)]
            )).map { try $0.toDomain() }
        }
    }

    func find(name: DishName) async throws -> Dish? {
        try await withPersistenceError {
            let raw = name.value
            return try await store.fetchOne(FetchDescriptor<DishModel>(
                predicate: #Predicate { $0.name == raw }
            ))?.toDomain()
        }
    }

    func save(_ dish: Dish) async throws {
        try await withPersistenceError {
            let id = dish.id
            let existing = try await store.fetchOne(FetchDescriptor<DishModel>(
                predicate: #Predicate { $0.id == id }
            ))
            if let existing {
                existing.update(from: dish)
            } else {
                await store.insert(DishModel(from: dish))
            }
            try await store.save()
        }
    }

    func delete(id: UUID) async throws {
        try await withPersistenceError {
            let logs = try await store.fetch(FetchDescriptor<DishLogModel>(
                predicate: #Predicate { $0.dishID == id }
            ))
            for log in logs {
                await store.delete(log)
            }
            // レシピも消す。残すと参照されないデータが溜まる。
            if let recipe = try await store.fetchOne(FetchDescriptor<RecipeModel>(
                predicate: #Predicate { $0.dishID == id }
            )) {
                await store.delete(recipe)
            }
            if let model = try await store.fetchOne(FetchDescriptor<DishModel>(
                predicate: #Predicate { $0.id == id }
            )) {
                await store.delete(model)
            }
            try await store.save()
        }
    }

    func fetchLogs(dishID: UUID) async throws -> [DishLog] {
        try await withPersistenceError {
            try await store.fetch(FetchDescriptor<DishLogModel>(
                predicate: #Predicate { $0.dishID == dishID },
                sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
            )).map { $0.toDomain() }
        }
    }

    func fetchLogs(mealRecordID: UUID) async throws -> [DishLog] {
        try await withPersistenceError {
            try await store.fetch(FetchDescriptor<DishLogModel>(
                predicate: #Predicate { $0.mealRecordID == mealRecordID },
                sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
            )).map { $0.toDomain() }
        }
    }

    func save(_ log: DishLog) async throws {
        try await withPersistenceError {
            let id = log.id
            let existing = try await store.fetchOne(FetchDescriptor<DishLogModel>(
                predicate: #Predicate { $0.id == id }
            ))
            if let existing {
                existing.update(from: log)
            } else {
                await store.insert(DishLogModel(from: log))
            }
            try await store.save()
        }
    }

    func deleteLog(id: UUID) async throws {
        try await withPersistenceError {
            guard let model = try await store.fetchOne(FetchDescriptor<DishLogModel>(
                predicate: #Predicate { $0.id == id }
            )) else { return }
            await store.delete(model)
            try await store.save()
        }
    }

    func findRecipe(dishID: UUID) async throws -> Recipe? {
        try await withPersistenceError {
            try await store.fetchOne(FetchDescriptor<RecipeModel>(
                predicate: #Predicate { $0.dishID == dishID }
            ))?.toDomain()
        }
    }

    func save(_ recipe: Recipe) async throws {
        try await withPersistenceError {
            let dishID = recipe.dishID
            let existing = try await store.fetchOne(FetchDescriptor<RecipeModel>(
                predicate: #Predicate { $0.dishID == dishID }
            ))
            if let existing {
                existing.update(from: recipe)
            } else {
                await store.insert(RecipeModel(from: recipe))
            }
            try await store.save()
        }
    }

    func deleteRecipe(dishID: UUID) async throws {
        try await withPersistenceError {
            guard let model = try await store.fetchOne(FetchDescriptor<RecipeModel>(
                predicate: #Predicate { $0.dishID == dishID }
            )) else { return }
            await store.delete(model)
            try await store.save()
        }
    }
}
