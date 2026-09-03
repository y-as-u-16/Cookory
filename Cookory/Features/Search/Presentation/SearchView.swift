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
                    Section(String(localized: L10n.searchDishesSection)) {
                        ForEach(viewModel.results.dishes) { item in
                            Button { onSelectDish(item.dish.id) } label: {
                                CookbookRowView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !viewModel.results.meals.isEmpty {
                    Section(String(localized: L10n.searchNotesSection)) {
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
        .navigationTitle(Text(L10n.searchTitle))
        .searchable(
            text: Binding(
                get: { viewModel.keyword },
                set: { viewModel.keywordChanged(to: $0) }
            ),
            prompt: Text(L10n.searchPrompt)
        )
        // 結果の上に文字を重ねると、どちらが本文か読み取れない。
        // 画面を占める形にして、異常であることを明示する。
        .overlay {
            if let message = viewModel.errorMessage {
                ContentUnavailableView {
                    Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
                .background(.background)
            }
        }
    }

    private var noMatchState: some View {
        ContentUnavailableView.search(text: viewModel.keyword)
    }
}
