import SwiftUI

/// 起動状態に応じて画面を出し分ける。
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        switch appEnvironment.state {
        case .loading:
            ProgressView()
        case .ready(let container):
            NavigationStackView(container: container, router: appEnvironment.router)
        case .failed:
            ContentUnavailableView(
                "データを読み込めませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("アプリを再起動してください")
            )
        }
    }
}

/// NavigationStack と Route の対応付け。
///
/// 遷移先の View がまだ無い Route はプレースホルダを返す。
/// 各 Feature の Issue で順次差し替える。
private struct NavigationStackView: View {
    let container: DependencyContainer
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ContentView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .dependencies(container)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .mealDetail(let id):
            Text("食事記録 \(id.uuidString)")
        case .dishDetail(let id):
            Text("料理 \(id.uuidString)")
        case .calendar(let date):
            Text("カレンダー \(date.formatted(date: .abbreviated, time: .omitted))")
        case .settings:
            Text("設定")
        }
    }
}
