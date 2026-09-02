import SwiftUI

/// 同じ料理を作った履歴を時系列で見せる。本アプリの最重要の差別化画面。
struct DishDetailView: View {
    @State private var viewModel: DishDetailViewModel
    private let onOpenRecipe: () -> Void

    init(viewModel: DishDetailViewModel, onOpenRecipe: @escaping () -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onOpenRecipe = onOpenRecipe
    }

    var body: some View {
        ScrollView {
            content.padding()
        }
        .navigationTitle(viewModel.history?.dish.name.value ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            shareButton
            favoriteButton
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.shareImage != nil },
                set: { if !$0 { viewModel.dismissShare() } }
            )
        ) {
            if let image = viewModel.shareImage {
                ShareSheetView(image: image)
            }
        }
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
                Button(action: onOpenRecipe) {
                    Label(L10n.dishOpenRecipe, systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                if !history.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.dishHistoryTitle).font(.headline)
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
    private var shareButton: some View {
        if viewModel.history != nil {
            Button {
                Task { await viewModel.prepareShare() }
            } label: {
                if viewModel.isPreparingShare {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .accessibilityLabel(Text(L10n.dishShare))
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
            .accessibilityLabel(Text(history.dish.isFavorite ? L10n.dishRemoveFavorite : L10n.dishAddFavorite))
        }
    }
}

/// 共有シート。画像のプレビューを添えて渡す。
private struct ShareSheetView: View {
    let image: ShareImage

    var body: some View {
        VStack(spacing: 20) {
            if let uiImage = UIImage(data: image.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.hero))
            }
            ShareLink(item: image, preview: SharePreview("Cookory")) {
                Label(L10n.dishShare, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
        }
        .padding()
        .presentationDetents([.large])
    }
}
