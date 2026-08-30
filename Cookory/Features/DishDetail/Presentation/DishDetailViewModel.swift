import Foundation
import Observation

@MainActor
@Observable
final class DishDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(DishHistory)
        case failed(String)
    }

    private(set) var state: State = .loading

    private let dishID: UUID
    private let getDishHistory: GetDishHistoryUseCase

    init(dishID: UUID, getDishHistory: GetDishHistoryUseCase) {
        self.dishID = dishID
        self.getDishHistory = getDishHistory
    }

    var history: DishHistory? {
        guard case .loaded(let history) = state else { return nil }
        return history
    }

    func load() async {
        do {
            state = .loaded(try await getDishHistory.execute(dishID: dishID))
        } catch {
            state = .failed("読み込めませんでした。もう一度お試しください。")
        }
    }

    func toggleFavorite() async {
        guard let history else { return }
        do {
            let updated = try await getDishHistory.toggleFavorite(dishID: dishID)
            state = .loaded(DishHistory(dish: updated, entries: history.entries))
        } catch {
            state = .failed("変更を保存できませんでした。もう一度お試しください。")
        }
    }
}
