import Foundation
import SwiftData

/// ModelContext へのアクセスを直列化する。
///
/// ModelContext は Sendable ではないため、複数の Task から触ると壊れる。
/// @ModelActor が専用の Executor 上に Context を閉じ込め、外からは await 越しに
/// しか触れないようにする。Repository はすべてこの Store を経由する。
@ModelActor
actor SwiftDataStore {
    /// アプリ本体用。ディスクに永続化する。
    static func makePersistent() throws -> SwiftDataStore {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: CookoryMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
        return SwiftDataStore(modelContainer: container)
    }

    /// テストとプレビュー用。プロセス終了で消える。
    static func makeInMemory() throws -> SwiftDataStore {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataStore(modelContainer: container)
    }

    // MARK: - Primitives

    func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var limited = descriptor
        limited.fetchLimit = 1
        return try modelContext.fetch(limited).first
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        try modelContext.fetch(descriptor)
    }

    func insert<T: PersistentModel>(_ model: T) {
        modelContext.insert(model)
    }

    func delete<T: PersistentModel>(_ model: T) {
        modelContext.delete(model)
    }

    func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}
