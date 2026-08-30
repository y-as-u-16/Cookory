import SwiftUI

/// 起動状態に応じて画面を出し分ける。
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    /// スプラッシュを見せ終えたか。読み込みが速く終わっても
    /// 一瞬で消えると点滅に見えるため、最低表示時間を設ける。
    @State private var hasFinishedSplash = false

    /// 最低表示時間。これ以上待たせない。起動から記録までを速く保つため。
    static let minimumSplashDuration: Duration = .milliseconds(900)

    /// 読み込みが終わり、かつ最低表示時間を過ぎたら本編を出す。
    /// 片方だけで判定すると、読み込みが遅いときに空白の画面が出る。
    private var isShowingSplash: Bool {
        if case .loading = appEnvironment.state { return true }
        return !hasFinishedSplash
    }

    var body: some View {
        ZStack {
            content
            if isShowingSplash {
                SplashView().transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: isShowingSplash)
        .task {
            try? await Task.sleep(for: Self.minimumSplashDuration)
            hasFinishedSplash = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appEnvironment.state {
        case .loading:
            // スプラッシュが覆っているので何も出さない。
            Color.clear
        case .ready(let container):
            MainTabView(container: container, routers: appEnvironment.routers)
        case .failed:
            ContentUnavailableView(
                String(localized: L10n.loadFailedTitle),
                systemImage: "exclamationmark.triangle",
                description: Text(L10n.loadFailedDescription)
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
            MealDetailView(
                viewModel: MealDetailViewModel(
                    mealID: id,
                    getMealDetail: container.getMealDetail,
                    updateMealRecord: container.updateMealRecord,
                    assignDishToMeal: container.assignDishToMeal,
                    deleteMealRecord: container.deleteMealRecord
                ),
                onSelectDish: { router.push(.dishDetail($0)) },
                onDeleted: { router.pop() }
            )
        case .recipe(let id):
            RecipeEditorView(
                viewModel: RecipeEditorViewModel(dishID: id, editRecipe: container.editRecipe)
            )
        case .dishDetail(let id):
            DishDetailView(
                viewModel: DishDetailViewModel(
                    dishID: id,
                    getDishHistory: container.getDishHistory,
                    shareDish: container.shareDish
                ),
                onOpenRecipe: { router.push(.recipe(id)) }
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
                viewModel: CaptureViewModel(createMealRecord: container.createMealRecord),
                onSaved: { router.push(.mealDetail($0)) }
            )
        case .settings:
            SettingsView(
                viewModel: SettingsViewModel(exportData: container.exportData)
            )
        }
    }
}

extension AppTab {
    var title: LocalizedStringResource {
        switch self {
        case .home: L10n.tabHome
        case .calendar: L10n.tabCalendar
        case .cookbook: L10n.tabCookbook
        case .search: L10n.tabSearch
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
