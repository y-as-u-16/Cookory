import Foundation
import Observation

/// 撮影した写真を保存する画面の状態。
///
/// UseCase を呼ぶだけで、Repository や SwiftData には触れない（ARCHITECTURE.md #28）。
@MainActor
@Observable
final class CaptureViewModel {
    enum State: Equatable {
        case idle
        case saving
        case saved(MealRecord)
        case failed(String)
    }

    private(set) var state: State = .idle

    private let createMealRecord: CreateMealRecordUseCase

    init(createMealRecord: CreateMealRecordUseCase) {
        self.createMealRecord = createMealRecord
    }

    var isSaving: Bool { state == .saving }

    /// 保存された記録。入力画面はこれを受け取って料理名などを足す。
    var savedRecord: MealRecord? {
        guard case .saved(let meal) = state else { return nil }
        return meal
    }

    func save(image: Data, occurredAt: Date = Date()) async {
        // 二重送信を防ぐ。保存ボタンの連打で記録が 2 件できると、
        // 利用者は重複に気づかないまま片方だけを編集することになる。
        guard !isSaving else { return }

        state = .saving
        do {
            state = .saved(try await createMealRecord.execute(image: image, occurredAt: occurredAt))
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// 失敗後にやり直せるようにする。
    func reset() {
        state = .idle
    }

    /// DomainError を利用者向けの文言に翻訳する。
    /// エラーの内部表現をそのまま見せない（ARCHITECTURE.md #61）。
    private static func message(for error: Error) -> String {
        guard let domainError = error as? DomainError else {
            return "保存できませんでした。もう一度お試しください。"
        }
        switch domainError {
        case .imageStorageFailed:
            return "写真を保存できませんでした。空き容量をご確認ください。"
        case .persistenceFailed:
            return "記録を保存できませんでした。もう一度お試しください。"
        case .invalidInput(let reason):
            return reason
        case .notFound:
            return "対象が見つかりませんでした。"
        }
    }
}
