import Foundation
import Testing
@testable import Cookory

/// Fake 自体の検証。以降の UseCase テストがこの振る舞いに依存するため、
/// ここが正しくないとテスト全体が信用できなくなる。
struct InMemoryMealRecordRepositoryTests {
    private func makeRecord(daysAgo: Int) -> MealRecord {
        MealRecord(occurredAt: Date(timeIntervalSince1970: 1_800_000_000 - Double(daysAgo) * 86_400))
    }

    @Test func 保存した記録をIDで取得できる() async throws {
        let repository = InMemoryMealRecordRepository()
        let record = makeRecord(daysAgo: 0)

        try await repository.save(record)

        #expect(try await repository.find(id: record.id) == record)
    }

    @Test func 存在しないIDはnilを返す() async throws {
        let repository = InMemoryMealRecordRepository()

        #expect(try await repository.find(id: UUID()) == nil)
    }

    @Test func 同じIDで保存すると上書きされる() async throws {
        let repository = InMemoryMealRecordRepository()
        let record = makeRecord(daysAgo: 0)
        try await repository.save(record)

        try await repository.save(record.edited(mealType: .dinner, note: "追記"))

        #expect(await repository.count == 1)
        #expect(try await repository.find(id: record.id)?.mealType == .dinner)
    }

    @Test func 削除すると取得できなくなる() async throws {
        let repository = InMemoryMealRecordRepository()
        let record = makeRecord(daysAgo: 0)
        try await repository.save(record)

        try await repository.delete(id: record.id)

        #expect(try await repository.find(id: record.id) == nil)
    }

    @Test func 存在しないIDの削除は失敗しない() async throws {
        let repository = InMemoryMealRecordRepository()

        try await repository.delete(id: UUID())

        #expect(await repository.count == 0)
    }

    @Test func 最近の記録は新しい順に返る() async throws {
        let old = makeRecord(daysAgo: 10)
        let recent = makeRecord(daysAgo: 1)
        let middle = makeRecord(daysAgo: 5)
        let repository = InMemoryMealRecordRepository(seed: [old, recent, middle])

        let result = try await repository.fetchRecent(limit: 10)

        #expect(result.map(\.id) == [recent.id, middle.id, old.id])
    }

    @Test func limitを超える件数は返さない() async throws {
        let repository = InMemoryMealRecordRepository(
            seed: (0..<5).map { makeRecord(daysAgo: $0) }
        )

        #expect(try await repository.fetchRecent(limit: 2).count == 2)
    }

    @Test func エラーを注入すると保存が失敗する() async throws {
        let repository = InMemoryMealRecordRepository()
        await repository.setError(.persistenceFailed)

        await #expect(throws: DomainError.persistenceFailed) {
            try await repository.save(makeRecord(daysAgo: 0))
        }
    }
}
