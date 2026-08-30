import Foundation

/// 写真から食事記録を作る。アプリの中核となる操作。
///
/// 料理名も評価も要求しない。写真だけで記録が成立することが
/// 「記録するときは極限までシンプルに」という原則の実装（APP_DESIGN.md）。
struct CreateMealRecordUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let imageStorage: ImageStorage

    init(mealRepository: MealRecordRepository, imageStorage: ImageStorage) {
        self.mealRepository = mealRepository
        self.imageStorage = imageStorage
    }

    /// - Parameters:
    ///   - images: 保存する画像の実体。1 回の食卓に複数枚を残せる。
    ///   - occurredAt: 食事をした日時。撮影時刻とは限らないため呼び出し側が渡す。
    /// - Returns: 保存された食事記録。
    /// - Throws: 画像が 1 枚も無い場合は ``DomainError/invalidInput(reason:)``、
    ///   画像の保存に失敗した場合は ``DomainError/imageStorageFailed``、
    ///   永続化に失敗した場合は ``DomainError/persistenceFailed``。
    @discardableResult
    func execute(images: [Data], occurredAt: Date, now: Date = Date()) async throws -> MealRecord {
        guard !images.isEmpty else {
            throw DomainError.invalidInput(reason: "写真が選択されていません")
        }

        // 画像を先に保存する。順序が逆だと、記録だけが残って写真の無い
        // 食事記録が生まれる。逆順なら孤児ファイルが残るだけで後から回収できる。
        var assets: [PhotoAsset] = []
        do {
            for image in images {
                assets.append(try await imageStorage.save(image))
            }
        } catch {
            // 途中で失敗したら、それまでに保存した分も取り消す。
            // 記録が作られない以上、参照する術がないため。
            await rollback(assets)
            throw error
        }

        let meal = MealRecord(
            occurredAt: occurredAt,
            photoIDs: assets.map(\.id),
            createdAt: now
        )

        do {
            try await mealRepository.save(meal)
        } catch {
            await rollback(assets)
            throw error
        }

        return meal
    }

    /// 削除に失敗しても元のエラーを優先して伝えるため、結果は見ない。
    private func rollback(_ assets: [PhotoAsset]) async {
        for asset in assets {
            try? await imageStorage.delete(id: asset.id)
        }
    }
}
