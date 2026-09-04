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
            try await store.perform { context in
                try context.fetchOne(FetchDescriptor<DishModel>(
                    predicate: #Predicate { $0.id == id }
                ))?.toDomain()
            }
        }
    }

    func fetchAll() async throws -> [Dish] {
        try await withPersistenceError {
            try await store.perform { context in
                try context.fetch(FetchDescriptor<DishModel>(
                    sortBy: [SortDescriptor(\.name)]
                )).map { try $0.toDomain() }
            }
        }
    }

    func find(name: DishName) async throws -> Dish? {
        try await withPersistenceError {
            let raw = name.value
            return try await store.perform { context in
                try context.fetchOne(FetchDescriptor<DishModel>(
                    predicate: #Predicate { $0.name == raw }
                ))?.toDomain()
            }
        }
    }

    func save(_ dish: Dish) async throws {
        try await withPersistenceError {
            let id = dish.id
            try await store.performAndSave { context in
                let existing = try context.fetchOne(FetchDescriptor<DishModel>(
                    predicate: #Predicate { $0.id == id }
                ))
                if let existing {
                    existing.update(from: dish)
                } else {
                    context.insert(DishModel(from: dish))
                }
            }
        }
    }

    func delete(id: UUID) async throws {
        try await withPersistenceError {
            try await store.performAndSave { context in
                let logs = try context.fetch(FetchDescriptor<DishLogModel>(
                    predicate: #Predicate { $0.dishID == id }
                ))
                for log in logs {
                    context.delete(log)
                }
                // レシピも消す。残すと参照されないデータが溜まる。
                if let recipe = try context.fetchOne(FetchDescriptor<RecipeModel>(
                    predicate: #Predicate { $0.dishID == id }
                )) {
                    context.delete(recipe)
                }
                if let model = try context.fetchOne(FetchDescriptor<DishModel>(
                    predicate: #Predicate { $0.id == id }
                )) {
                    context.delete(model)
                }
            }
        }
    }

    func fetchLogs(dishID: UUID) async throws -> [DishLog] {
        try await withPersistenceError {
            try await store.perform { context in
                try context.fetch(FetchDescriptor<DishLogModel>(
                    predicate: #Predicate { $0.dishID == dishID },
                    sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
                )).map { $0.toDomain() }
            }
        }
    }

    func fetchLogs(mealRecordID: UUID) async throws -> [DishLog] {
        try await withPersistenceError {
            try await store.perform { context in
                try context.fetch(FetchDescriptor<DishLogModel>(
                    predicate: #Predicate { $0.mealRecordID == mealRecordID },
                    sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
                )).map { $0.toDomain() }
            }
        }
    }

    func save(_ log: DishLog) async throws {
        try await withPersistenceError {
            let id = log.id
            try await store.performAndSave { context in
                let existing = try context.fetchOne(FetchDescriptor<DishLogModel>(
                    predicate: #Predicate { $0.id == id }
                ))
                if let existing {
                    existing.update(from: log)
                } else {
                    context.insert(DishLogModel(from: log))
                }
            }
        }
    }

    func deleteLog(id: UUID) async throws {
        try await withPersistenceError {
            try await store.performAndSave { context in
                guard let model = try context.fetchOne(FetchDescriptor<DishLogModel>(
                    predicate: #Predicate { $0.id == id }
                )) else { return }
                context.delete(model)
            }
        }
    }

    func findRecipe(dishID: UUID) async throws -> Recipe? {
        try await withPersistenceError {
            try await store.perform { context in
                try context.fetchOne(FetchDescriptor<RecipeModel>(
                    predicate: #Predicate { $0.dishID == dishID }
                ))?.toDomain()
            }
        }
    }

    func save(_ recipe: Recipe) async throws {
        try await withPersistenceError {
            let dishID = recipe.dishID
            try await store.performAndSave { context in
                let existing = try context.fetchOne(FetchDescriptor<RecipeModel>(
                    predicate: #Predicate { $0.dishID == dishID }
                ))
                if let existing {
                    existing.update(from: recipe)
                } else {
                    context.insert(RecipeModel(from: recipe))
                }
            }
        }
    }

    func deleteRecipe(dishID: UUID) async throws {
        try await withPersistenceError {
            try await store.performAndSave { context in
                guard let model = try context.fetchOne(FetchDescriptor<RecipeModel>(
                    predicate: #Predicate { $0.dishID == dishID }
                )) else { return }
                context.delete(model)
            }
        }
    }
}
