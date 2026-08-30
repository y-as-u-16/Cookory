import Foundation
import Observation

@MainActor
@Observable
final class DishDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(DishHistory)
        case failed(LocalizedStringResource)
    }

    private(set) var state: State = .loading

    /// 共有用に書き出した画像。共有シートへ渡す。
    private(set) var shareImage: ShareImage?
    private(set) var isPreparingShare = false

    private let dishID: UUID
    private let getDishHistory: GetDishHistoryUseCase
    private let shareDish: ShareDishUseCase

    init(
        dishID: UUID,
        getDishHistory: GetDishHistoryUseCase,
        shareDish: ShareDishUseCase
    ) {
        self.dishID = dishID
        self.getDishHistory = getDishHistory
        self.shareDish = shareDish
    }

    func prepareShare() async {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            shareImage = ShareImage(data: try await shareDish.execute(dishID: dishID))
        } catch {
            state = .failed(L10n.errorGeneric)
        }
    }

    func dismissShare() {
        shareImage = nil
    }

    var history: DishHistory? {
        guard case .loaded(let history) = state else { return nil }
        return history
    }

    func load() async {
        do {
            state = .loaded(try await getDishHistory.execute(dishID: dishID))
        } catch {
            state = .failed(L10n.errorLoad)
        }
    }

    func toggleFavorite() async {
        guard let history else { return }
        do {
            let updated = try await getDishHistory.toggleFavorite(dishID: dishID)
            state = .loaded(DishHistory(dish: updated, entries: history.entries))
        } catch {
            state = .failed(L10n.errorSave)
        }
    }
}
