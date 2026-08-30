import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum State: Equatable {
        case loading
        case loaded(HomeContent)
        case failed(LocalizedStringResource)
    }

    private(set) var state: State = .loading

    private let getHomeContent: GetHomeContentUseCase

    init(getHomeContent: GetHomeContentUseCase) {
        self.getHomeContent = getHomeContent
    }

    var content: HomeContent? {
        guard case .loaded(let content) = state else { return nil }
        return content
    }

    /// 記録が 1 件も無い状態。初回起動時の案内を出すために使う。
    var isEmpty: Bool { content?.isEmpty ?? false }

    func load(now: Date = Date()) async {
        do {
            state = .loaded(try await getHomeContent.execute(now: now))
        } catch {
            state = .failed(L10n.errorLoad)
        }
    }
}
