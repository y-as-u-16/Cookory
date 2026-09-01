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
        let assets = try await saveImages(images)

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

    /// 写真をまとめて保存する。
    ///
    /// 1 枚ずつ順に処理すると、10 枚では 10 回ぶんの縮小と書き込みを待つことになる。
    /// 撮影直後の待ち時間に直結するため並行に走らせ、撮った順は添字で復元する。
    private func saveImages(_ images: [Data]) async throws -> [PhotoAsset] {
        var saved: [Int: PhotoAsset] = [:]

        do {
            try await withThrowingTaskGroup(of: (Int, PhotoAsset).self) { group in
                for (index, image) in images.enumerated() {
                    group.addTask { (index, try await imageStorage.save(image)) }
                }
                for try await (index, asset) in group {
                    saved[index] = asset
                }
            }
        } catch {
            // 失敗しても成功した分のファイルは残る。記録が作られない以上
            // 参照する術がないため消す。
            await rollback(Array(saved.values))
            throw error
        }

        return images.indices.compactMap { saved[$0] }
    }

    /// 削除に失敗しても元のエラーを優先して伝えるため、結果は見ない。
    private func rollback(_ assets: [PhotoAsset]) async {
        for asset in assets {
            try? await imageStorage.delete(id: asset.id)
        }
    }
}
