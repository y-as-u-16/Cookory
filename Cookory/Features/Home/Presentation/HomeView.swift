import SwiftUI

/// 今日記録することと、次に作る料理を思い出すことが目的（APP_DESIGN.md #7）。
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onRecord: () -> Void
    private let onSelectMeal: (UUID) -> Void
    private let onSelectDish: (UUID) -> Void

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
            VStack(alignment: .leading, spacing: 28) {
                recordButton
                content
            }
            .padding()
        }
        .navigationTitle("今日のごはん")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            Label("料理を記録", systemImage: "plus.circle.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        case .loaded(let content) where content.isEmpty:
            emptyState
        case .loaded(let content):
            loadedContent(content)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("まだ記録がありません", systemImage: "fork.knife")
        } description: {
            Text("作った料理を写真で残しておくと、ここに並びます。")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func loadedContent(_ content: HomeContent) -> some View {
        if !content.recentMeals.isEmpty {
            TitledSection(title: "最近の料理") {
                ForEach(content.recentMeals) { meal in
                    Button { onSelectMeal(meal.id) } label: {
                        MealRowView(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !content.forgottenDishes.isEmpty {
            TitledSection(title: "久しぶりにどう？") {
                ForEach(content.forgottenDishes) { forgotten in
                    Button { onSelectDish(forgotten.dish.id) } label: {
                        ForgottenDishRowView(forgotten: forgotten)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 見出し付きのまとまり。SwiftUI の Section は List 前提のため自前で持つ。
private struct TitledSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
    }
}
