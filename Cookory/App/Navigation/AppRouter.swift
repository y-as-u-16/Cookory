import Foundation
import Observation

/// NavigationStack の path を保持する。
///
/// @MainActor なのは SwiftUI の描画と同じ文脈で更新されるため。
@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    /// タブごとに独立した Router を持つ。共有すると、あるタブで開いた
    /// 詳細画面が別のタブにも現れる。
    static func perTab() -> [AppTab: AppRouter] {
        Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, AppRouter()) })
    }

    init(path: [AppRoute] = []) {
        self.path = path
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// 指定の Route まで戻る。見つからなければ何もしない。
    /// 存在しない Route を指定したときに全部消えると、意図しない画面に飛ぶため。
    func pop(to route: AppRoute) {
        guard let index = path.lastIndex(of: route) else { return }
        path.removeSubrange((index + 1)...)
    }
}
