import Foundation

/// 食事記録を削除する。写真と調理履歴もあわせて片づける。
struct DeleteMealRecordUseCase: Sendable {
    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository
    private let imageStorage: ImageStorage

    init(
        mealRepository: MealRecordRepository,
        dishRepository: DishRepository,
        imageStorage: ImageStorage
    ) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
        self.imageStorage = imageStorage
    }

    /// 存在しない ID を渡しても失敗させない。削除の再実行を安全にするため。
    ///
    /// Dish 自体は消さない。作った履歴が 0 件になっても「唐揚げを作れる」という
    /// 事実は残るため、Cookbook から料理が消えるのは利用者の意図と異なる。
    func execute(id: UUID) async throws {
        guard let meal = try await mealRepository.find(id: id) else { return }

        for logID in meal.dishLogIDs {
            try await dishRepository.deleteLog(id: logID)
        }

        // 記録を先に消す。画像の削除が失敗しても、残るのは参照されない
        // ファイルだけで後から回収できる。逆順だと写真の無い記録が残る。
        try await mealRepository.delete(id: id)

        for photoID in meal.photoIDs {
            try await imageStorage.delete(id: photoID)
        }
    }
}
