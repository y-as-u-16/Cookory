import SwiftUI

/// 1 件の食事記録。写真・料理名・レシピ・メモをこの 1 画面で書き切る。
///
/// 記録直後にそのまま開く画面でもある。料理名とレシピを別画面に分けると
/// 「あとで書こう」が積み上がるため、入力欄はすべてここに集める。
struct MealDetailView: View {
    @State private var viewModel: MealDetailViewModel
    @State private var isConfirmingDelete = false
    @FocusState private var isEditingText: Bool

    private let onSelectDish: (UUID) -> Void
    private let onDeleted: () -> Void

    init(
        viewModel: MealDetailViewModel,
        onSelectDish: @escaping (UUID) -> Void,
        onDeleted: @escaping () -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSelectDish = onSelectDish
        self.onDeleted = onDeleted
    }

    var body: some View {
        Form {
            content
        }
        .navigationTitle(Text(L10n.mealDetailTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .toolbar {
            // 複数行入力では改行が入力になる。閉じる手段がないと入力が詰まる。
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: L10n.commonDone)) { isEditingText = false }
            }
        }
        .alert(
            Text(L10n.mealDetailDeleteConfirm), isPresented: $isConfirmingDelete
        ) {
            Button(String(localized: L10n.commonCancel), role: .cancel) {}
            Button(String(localized: L10n.mealDetailDelete), role: .destructive) {
                Task { if await viewModel.deleteMeal() { onDeleted() } }
            }
        } message: {
            Text(L10n.mealDetailDeleteMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        case .loaded(let detail):
            photoSection(detail)
            dishSection(detail)
            noteSection(detail)

            if let message = viewModel.errorMessage {
                Section {
                    // 色だけで異常を示さない。アイコンを添える。
                    Label { Text(message) } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                }
            }

            saveSection
            deleteSection
        }
    }

    private func photoSection(_ detail: MealDetail) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(detail.meal.photoIDs.enumerated()), id: \.element) { index, photoID in
                        PhotoImageView(photoID: photoID, size: .hero)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel(
                                Text(L10n.a11yPhotoIndex(index + 1, detail.meal.photoIDs.count))
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(detail.meal.occurredAt.formatted(date: .long, time: .shortened))
        }
    }

    private func dishSection(_ detail: MealDetail) -> some View {
        Section {
            ForEach(detail.dishes) { entry in
                MealDishRowView(
                    entry: entry,
                    isExpanded: viewModel.isExpanded(dishID: entry.dish.id),
                    draft: viewModel.recipeDraft(for: entry.dish.id),
                    isEditingText: $isEditingText,
                    onToggle: {
                        Task { await viewModel.toggleExpansion(dishID: entry.dish.id) }
                    },
                    onAddLink: {
                        Task { await viewModel.addLink(dishID: entry.dish.id) }
                    },
                    onRemoveLink: { linkID in
                        Task { await viewModel.removeLink(dishID: entry.dish.id, linkID: linkID) }
                    },
                    onAddPhotos: { images in
                        Task { await viewModel.addRecipePhotos(dishID: entry.dish.id, images: images) }
                    },
                    onRemovePhoto: { photoID in
                        Task { await viewModel.removeRecipePhoto(dishID: entry.dish.id, photoID: photoID) }
                    },
                    onOpenHistory: { onSelectDish(entry.dish.id) }
                )
                // 打ち間違えた料理を、記録ごと消さずに外せるようにする。
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.removeDish(entry: entry) }
                    } label: {
                        Label(L10n.mealDetailRemoveDish, systemImage: "minus.circle")
                    }
                }
            }

            HStack {
                TextField(String(localized: L10n.mealDetailAddDish), text: $viewModel.dishNameDraft)
                    .submitLabel(.done)
                    .focused($isEditingText)
                    .onSubmit { Task { await viewModel.addDish() } }
                Button(String(localized: L10n.mealDetailAdd)) {
                    Task { await viewModel.addDish() }
                }
                .disabled(!viewModel.canAddDish)
            }
        } header: {
            Text(L10n.mealDetailDishesSection)
        } footer: {
            if detail.hasDishes {
                Text(L10n.mealDetailDishHint)
            }
        }
    }

    private func noteSection(_ detail: MealDetail) -> some View {
        Section(String(localized: L10n.mealDetailNoteSection)) {
            TextField(String(localized: L10n.mealDetailNote), text: $viewModel.noteDraft, axis: .vertical)
                .lineLimit(3...8)
                .focused($isEditingText)
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                isEditingText = false
                Task { await viewModel.saveAll() }
            } label: {
                Text(L10n.mealDetailSave)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasUnsavedChanges)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            if viewModel.hasUnsavedChanges {
                Text(L10n.mealDetailUnsavedHint)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(String(localized: L10n.mealDetailDelete), role: .destructive) {
                isConfirmingDelete = true
            }
        }
    }
}
