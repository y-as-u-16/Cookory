import Foundation
import Testing
@testable import Cookory

@MainActor
struct AppEnvironmentTests {
    @Test func 初期状態はloading() {
        let environment = AppEnvironment()

        guard case .loading = environment.state else {
            Issue.record("初期状態が loading ではありません")
            return
        }
    }

    @Test func 組み立てに成功するとreadyになる() {
        let environment = AppEnvironment()

        environment.bootstrap { try DependencyContainer.inMemory() }

        guard case .ready = environment.state else {
            Issue.record("ready になっていません")
            return
        }
    }

    /// 初期化の失敗でクラッシュさせない。利用者にはただの強制終了に見えるため。
    @Test func 組み立てに失敗してもクラッシュしない() {
        let environment = AppEnvironment()

        environment.bootstrap { throw DomainError.persistenceFailed }

        guard case .failed = environment.state else {
            Issue.record("failed になっていません")
            return
        }
    }
}
