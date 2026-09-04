import Foundation
import Testing
@testable import Cookory

/// 永続化層の例外が Domain へ渡るときの翻訳。
///
/// SwiftData の例外をそのまま上げると Presentation が内部表現に依存する。
/// 逆に何でも persistenceFailed に潰すと、入力不正と保存失敗を区別できない。
struct PersistenceErrorMappingTests {
    private struct StorageFailure: Error {}

    @Test func 未知の例外はpersistenceFailedになる() async throws {
        await #expect(throws: DomainError.persistenceFailed) {
            try await withPersistenceError { throw StorageFailure() }
        }
    }

    /// Mapper が投げる invalidInput を潰すと、壊れたデータなのか
    /// 保存に失敗したのかが分からなくなる。
    @Test func DomainErrorはそのまま通る() async throws {
        let reason = "保存された料理名が不正です"

        await #expect(throws: DomainError.invalidInput(reason: reason)) {
            try await withPersistenceError {
                throw DomainError.invalidInput(reason: reason)
            }
        }
    }

    @Test func notFoundもそのまま通る() async throws {
        let id = UUID()

        await #expect(throws: DomainError.notFound(id: id)) {
            try await withPersistenceError { throw DomainError.notFound(id: id) }
        }
    }

    @Test func 例外がなければ値をそのまま返す() async throws {
        let value = try await withPersistenceError { 42 }

        #expect(value == 42)
    }
}
