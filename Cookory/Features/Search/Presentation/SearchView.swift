import SwiftUI

/// 料理名とメモを対象にした検索。
struct SearchView: View {
    @State private var viewModel: SearchViewModel
    private let onSelectDish: (UUID) -> Void
    private let onSelectMeal: (UUID) -> Void

    init(
        viewModel: SearchViewModel,
        onSelectDish: @escaping (UUID) -> Void,
        onSelectMeal: @escaping (UUID) -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSelectDish = onSelectDish
        self.onSelectMeal = onSelectMeal
    }

    var body: some View {
        List {
            if viewModel.hasNoMatch {
                noMatchState.listRowSeparator(.hidden)
            } else {
                if !viewModel.results.dishes.isEmpty {
                    Section("料理") {
                        ForEach(viewModel.results.dishes) { item in
                            Button { onSelectDish(item.dish.id) } label: {
                                CookbookRowView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !viewModel.results.meals.isEmpty {
                    Section("メモ") {
                        ForEach(viewModel.results.meals) { meal in
                            Button { onSelectMeal(meal.id) } label: {
                                MealRowView(meal: meal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("検索")
        .searchable(
            text: Binding(
                get: { viewModel.keyword },
                set: { viewModel.keywordChanged(to: $0) }
            ),
            prompt: "料理名・メモ"
        )
        .overlay {
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.secondary)
            }
        }
    }

    private var noMatchState: some View {
        ContentUnavailableView.search(text: viewModel.keyword)
    }
}
