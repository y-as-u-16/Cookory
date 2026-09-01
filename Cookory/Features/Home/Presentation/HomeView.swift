import SwiftUI

/// 今日記録することと、次に作る料理を思い出すことが目的（APP_DESIGN.md #7）。
///
/// 記録が増えるほど出せるものが増える構成にしている。ただし
/// 「あと N 件で解放」のような提示はしない。数を追わせると、
/// 料理そのものの楽しさが目的から手段へ変わる。
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onRecord: () -> Void
    private let onSelectMeal: (UUID) -> Void
    private let onSelectDish: (UUID) -> Void

    private static let carouselItemSize: CGFloat = 140

    init(
        viewModel: HomeViewModel,
        onRecord: @escaping () -> Void,
        onSelectMeal: @escaping (UUID) -> Void,
        onSelectDish: @escaping (UUID) -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onRecord = onRecord
        self.onSelectMeal = onSelectMeal
        self.onSelectDish = onSelectDish
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(Text(L10n.homeTitle))
        // 詳細画面で削除して戻ったときに反映させるため、表示のたびに取り直す。
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        case .loaded(let content) where content.isEmpty:
            emptyState
        case .loaded(let content):
            loadedContent(content)
        }
    }

    // MARK: - 記録がある状態

    @ViewBuilder
    private func loadedContent(_ content: HomeContent) -> some View {
        if content.summary.isWorthShowing {
            summaryLine(content.summary)
        }

        if let latest = content.recentMeals.first {
            Button { onSelectMeal(latest.meal.id) } label: {
                MealHeroCard(recent: latest)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recentMealRow")
        }

        recordButton

        // 2 件目以降を横に並べる。1 件しかないならヒーローで足りる。
        if content.recentMeals.count > 1 {
            TitledSection(title: L10n.homeRecentTitle) {
                recentCarousel(Array(content.recentMeals.dropFirst()))
            }
        }

        if !content.forgottenDishes.isEmpty {
            TitledSection(title: L10n.homeForgottenTitle) {
                forgottenRow(content.forgottenDishes)
            }
        }
    }

    /// 続いていることだけを伝える。途切れても責めない書き方にする。
    private func summaryLine(_ summary: CookingSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.homeWeeklyCount(summary.daysCookedThisWeek))
                .font(.title3.weight(.semibold))
            Text(L10n.homeTotalCount(summary.totalRecords, summary.distinctDishes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func recentCarousel(_ meals: [RecentMeal]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(meals) { recent in
                    Button { onSelectMeal(recent.meal.id) } label: {
                        MealCarouselCell(recent: recent, size: Self.carouselItemSize)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
        // 端まで写真を見せつつ、次のカードが覗く形にする。
        .scrollClipDisabled()
    }

    private func forgottenRow(_ dishes: [ForgottenDish]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(dishes) { forgotten in
                    Button { onSelectDish(forgotten.dish.id) } label: {
                        ForgottenDishCard(forgotten: forgotten, size: Self.carouselItemSize)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            Label(L10n.homeRecordButton, systemImage: "plus.circle.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - 記録が無い状態

    /// 空の枠を薄く見せる。写真中心のアプリでは「ここに写真が入る」ことを
    /// 図で示すほうが、イラストや文章より伝わる。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            GhostMealCard()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.homeEmptyTitle).font(.headline)
                Text(L10n.homeEmptyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            recordButton
        }
        .padding(.top, 8)
    }
}

/// 見出し付きのまとまり。SwiftUI の Section は List 前提のため自前で持つ。
private struct TitledSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
    }
}
