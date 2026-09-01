import SwiftUI

/// 実際に作った料理だけが並ぶ「わが家の料理図鑑」（APP_DESIGN.md）。
struct CookbookView: View {
    @State private var viewModel: CookbookViewModel
    private let onSelectDish: (UUID) -> Void

    init(viewModel: CookbookViewModel, onSelectDish: @escaping (UUID) -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSelectDish = onSelectDish
    }

    var body: some View {
        List {
            if viewModel.isEmpty {
                emptyState.listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.items) { item in
                    Button { onSelectDish(item.dish.id) } label: {
                        CookbookRowView(item: item)
                            // 行全体をタップ対象にする。label だけだと余白が
                            // 反応せず、行の端を押しても遷移しない。
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cookbookRow")
                }
                if viewModel.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task { await viewModel.loadMore() }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text(L10n.cookbookTitle))
        .toolbar { sortMenu }
        // 詳細画面で削除して戻ったときに反映させるため、表示のたびに取り直す。
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CookbookSort.allCases, id: \.self) { sort in
                Button {
                    Task { await viewModel.changeSort(to: sort) }
                } label: {
                    if viewModel.sort == sort {
                        Label { Text(sort.displayName) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(sort.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L10n.cookbookEmptyTitle, systemImage: "book.closed")
        } description: {
            Text(L10n.cookbookEmptyDescription)
        }
    }
}

extension CookbookSort {
    /// 表示名は Presentation の責務。Domain 側には持たせない。
    var displayName: LocalizedStringResource {
        switch self {
        case .recentlyCooked: L10n.sortRecentlyCooked
        case .mostCooked: L10n.sortMostCooked
        case .notCookedRecently: L10n.sortNotCookedRecently
        case .favorite: L10n.sortFavorite
        case .name: L10n.sortName
        }
    }
}
