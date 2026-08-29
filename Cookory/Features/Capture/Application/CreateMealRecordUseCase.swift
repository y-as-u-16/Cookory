import Foundation

/// 写真から食事記録を作る。アプリの中核となる操作。
///
/// 料理名も評価も要求しない。写真 1 枚で記録が成立することが
/// 「記録するときは極限までシンプルに」という原則の実装（APP_DESIGN.md）。
struct CreateMealRecordUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let imageStorage: ImageStorage

    init(mealRepository: MealRecordRepository, imageStorage: ImageStorage) {
        self.mealRepository = mealRepository
        self.imageStorage = imageStorage
    }

    /// - Parameters:
    ///   - image: 保存する画像の実体。
    ///   - occurredAt: 食事をした日時。撮影時刻とは限らないため呼び出し側が渡す。
    /// - Returns: 保存された食事記録。
    /// - Throws: 画像の保存に失敗した場合は ``DomainError/imageStorageFailed``、
    ///   永続化に失敗した場合は ``DomainError/persistenceFailed``。
    @discardableResult
    func execute(image: Data, occurredAt: Date, now: Date = Date()) async throws -> MealRecord {
        // 画像を先に保存する。順序が逆だと、記録だけが残って写真の無い
        // 食事記録が生まれる。逆順なら孤児ファイルが残るだけで後から回収できる。
        let asset = try await imageStorage.save(image)

        let meal = MealRecord(
            occurredAt: occurredAt,
            photoIDs: [asset.id],
            createdAt: now
        )

        do {
            try await mealRepository.save(meal)
        } catch {
            // 記録が残らない以上、この写真を参照する術がない。
            // 削除に失敗しても元のエラーを優先して伝える。
            try? await imageStorage.delete(id: asset.id)
            throw error
        }

        return meal
    }
}
