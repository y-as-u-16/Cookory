import Foundation

/// Domain 層が表明するエラー。
///
/// 永続化やネットワークの失敗をそのまま UI へ流さないための境界。
/// SwiftData や Supabase 固有のエラーは Data 層でこの型に翻訳する。
enum DomainError: Error, Equatable, Sendable {
    /// 指定された ID の対象が存在しない。
    case notFound(id: UUID)

    /// 入力が Domain の制約を満たさない。
    case invalidInput(reason: String)

    /// 永続化層の失敗。原因の詳細は Data 層でログに残し、ここには残さない。
    case persistenceFailed

    /// 画像の保存・読み出しに失敗した。
    case imageStorageFailed
}
