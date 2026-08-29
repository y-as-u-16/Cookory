import Foundation

/// SwiftData 由来の例外を DomainError に翻訳する。
///
/// DomainError はそのまま通す。Mapper が投げる invalidInput を
/// persistenceFailed で潰すと、原因の切り分けができなくなるため。
func withPersistenceError<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as DomainError {
        throw error
    } catch {
        throw DomainError.persistenceFailed
    }
}
