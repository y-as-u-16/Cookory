import SwiftUI

/// 同じ料理を作った履歴を時系列で見せる。本アプリの最重要の差別化画面。
struct DishDetailView: View {
    @State private var viewModel: DishDetailViewModel

    init(viewModel: DishDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            content.padding()
        }
        .navigationTitle(viewModel.history?.dish.name.value ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { favoriteButton }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        case .loaded(let history):
            VStack(alignment: .leading, spacing: 24) {
                DishSummaryView(history: history)
                if !history.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("履歴").font(.headline)
                        ForEach(history.entries) { entry in
                            DishHistoryRowView(entry: entry)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if let history = viewModel.history {
            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Image(systemName: history.dish.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(history.dish.isFavorite ? .pink : .secondary)
            }
            .accessibilityLabel(history.dish.isFavorite ? "お気に入りを解除" : "お気に入りに追加")
        }
    }
}
