import SwiftUI

/// DependencyContainer を SwiftUI の Environment に載せるための橋渡し。
///
/// EnvironmentKey に defaultValue を置かない。組み立てに失敗し得る依存に
/// 既定値を与えると、配線を忘れた View が黙って別のストレージを使い始める。
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var dependencies: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    func dependencies(_ container: DependencyContainer) -> some View {
        environment(\.dependencies, container)
    }
}

/// アプリ起動時の状態。
///
/// 永続化の初期化は失敗し得る。fatalError で落とすと利用者には
/// ただのクラッシュにしか見えないため、失敗を状態として持つ。
@MainActor
@Observable
final class AppEnvironment {
    enum State {
        case loading
        case ready(DependencyContainer)
        case failed
    }

    private(set) var state: State = .loading
    let router = AppRouter()

    func bootstrap(using build: () throws -> DependencyContainer = { try DependencyContainer.live() }) {
        do {
            state = .ready(try build())
        } catch {
            state = .failed
        }
    }
}
