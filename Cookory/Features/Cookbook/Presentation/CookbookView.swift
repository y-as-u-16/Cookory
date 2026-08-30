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
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task { await viewModel.loadMore() }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("わが家の料理図鑑")
        .toolbar { sortMenu }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CookbookSort.allCases, id: \.self) { sort in
                Button {
                    Task { await viewModel.changeSort(to: sort) }
                } label: {
                    if viewModel.sort == sort {
                        Label(sort.displayName, systemImage: "checkmark")
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
            Label("まだ料理がありません", systemImage: "book.closed")
        } description: {
            Text("記録した料理に名前を付けると、ここに集まります。")
        }
    }
}

extension CookbookSort {
    /// 表示名は Presentation の責務。Domain 側には持たせない。
    var displayName: String {
        switch self {
        case .recentlyCooked: "最近作った"
        case .mostCooked: "よく作る"
        case .notCookedRecently: "最近作っていない"
        case .favorite: "お気に入り"
        case .name: "名前順"
        }
    }
}
