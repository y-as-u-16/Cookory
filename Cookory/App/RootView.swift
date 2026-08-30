import SwiftUI

/// 起動状態に応じて画面を出し分ける。
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        switch appEnvironment.state {
        case .loading:
            ProgressView()
        case .ready(let container):
            MainTabView(container: container, routers: appEnvironment.routers)
        case .failed:
            ContentUnavailableView(
                "データを読み込めませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("アプリを再起動してください")
            )
        }
    }
}

/// 4 つのタブ。それぞれが独立した NavigationStack を持つ。
private struct MainTabView: View {
    let container: DependencyContainer
    let routers: [AppTab: AppRouter]

    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabStack(tab: tab, container: container, router: routers[tab] ?? AppRouter())
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .dependencies(container)
    }
}

/// 1 タブ分の NavigationStack。
private struct TabStack: View {
    let tab: AppTab
    let container: DependencyContainer
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch tab {
        case .home:
            HomeView(
                viewModel: HomeViewModel(getHomeContent: container.getHomeContent),
                onRecord: { router.push(.capture) },
                onSelectMeal: { router.push(.mealDetail($0)) },
                onSelectDish: { router.push(.dishDetail($0)) }
            )
            .toolbar { settingsButton }
        case .calendar:
            CalendarView(
                viewModel: CalendarViewModel(query: container.calendarMealQuery),
                onSelectMeal: { router.push(.mealDetail($0)) }
            )
        case .cookbook:
            CookbookView(
                viewModel: CookbookViewModel(query: container.cookbookQuery),
                onSelectDish: { router.push(.dishDetail($0)) }
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(query: container.searchQuery),
                onSelectDish: { router.push(.dishDetail($0)) },
                onSelectMeal: { router.push(.mealDetail($0)) }
            )
        }
    }

    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.push(.settings) } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("設定")
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .mealDetail(let id):
            Text("食事記録 \(id.uuidString)")
        case .dishDetail(let id):
            DishDetailView(
                viewModel: DishDetailViewModel(
                    dishID: id, getDishHistory: container.getDishHistory
                )
            )
        case .calendar(let month):
            CalendarView(
                viewModel: CalendarViewModel(query: container.calendarMealQuery, now: month),
                onSelectMeal: { router.push(.mealDetail($0)) }
            )
        case .cookbook:
            CookbookView(
                viewModel: CookbookViewModel(query: container.cookbookQuery),
                onSelectDish: { router.push(.dishDetail($0)) }
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(query: container.searchQuery),
                onSelectDish: { router.push(.dishDetail($0)) },
                onSelectMeal: { router.push(.mealDetail($0)) }
            )
        case .capture:
            CaptureView(
                viewModel: CaptureViewModel(createMealRecord: container.createMealRecord)
            )
        case .settings:
            SettingsView(
                viewModel: SettingsViewModel(exportData: container.exportData)
            )
        }
    }
}

extension AppTab {
    var title: String {
        switch self {
        case .home: "ホーム"
        case .calendar: "カレンダー"
        case .cookbook: "図鑑"
        case .search: "検索"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .calendar: "calendar"
        case .cookbook: "book"
        case .search: "magnifyingglass"
        }
    }
}
