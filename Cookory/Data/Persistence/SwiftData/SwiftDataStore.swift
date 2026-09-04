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

    /// Context を使う処理を Store の隔離下で実行し、Sendable な結果だけを返す。
    ///
    /// PersistentModel は自身が属する ModelContext への参照を持つため、actor の外へ
    /// 出して操作すると隔離が破れる。モデルに触る処理をこのクロージャに閉じ込め、
    /// 境界を越えるのは Domain 型だけにする。
    func perform<T: Sendable>(_ work: (ModelContext) throws -> T) throws -> T {
        try work(modelContext)
    }

    /// perform と同じだが、変更を確定させる。
    func performAndSave<T: Sendable>(_ work: (ModelContext) throws -> T) throws -> T {
        let result = try work(modelContext)
        guard modelContext.hasChanges else { return result }
        try modelContext.save()
        return result
    }
}

extension ModelContext {
    func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var limited = descriptor
        limited.fetchLimit = 1
        return try fetch(limited).first
    }
}
