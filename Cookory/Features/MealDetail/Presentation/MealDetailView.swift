import SwiftUI

/// 1 件の食事記録。写真を見て、料理名やメモを後から足す画面。
struct MealDetailView: View {
    @State private var viewModel: MealDetailViewModel
    @State private var isConfirmingDelete = false

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
        .confirmationDialog(
            Text(L10n.mealDetailDeleteConfirm), isPresented: $isConfirmingDelete, titleVisibility: .visible
        ) {
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
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
            Section {
                Button(String(localized: L10n.mealDetailDelete), role: .destructive) { isConfirmingDelete = true }
            }
        }
    }

    private func photoSection(_ detail: MealDetail) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(detail.meal.photoIDs, id: \.self) { photoID in
                        PhotoImageView(photoID: photoID, size: .hero)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(detail.meal.occurredAt.formatted(date: .long, time: .shortened))
        }
    }

    private func dishSection(_ detail: MealDetail) -> some View {
        Section(String(localized: L10n.mealDetailDishesSection)) {
            ForEach(detail.dishes) { entry in
                Button { onSelectDish(entry.dish.id) } label: {
                    MealDishRowView(entry: entry)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                TextField(String(localized: L10n.mealDetailAddDish), text: $viewModel.dishNameDraft)
                    .submitLabel(.done)
                    .onSubmit { Task { await viewModel.addDish() } }
                Button(String(localized: L10n.mealDetailAdd)) {
                    Task { await viewModel.addDish() }
                }
                .disabled(!viewModel.canAddDish)
            }
        }
    }

    private func noteSection(_ detail: MealDetail) -> some View {
        Section(String(localized: L10n.mealDetailNoteSection)) {
            Picker(String(localized: L10n.mealDetailMealType), selection: $viewModel.mealTypeDraft) {
                Text(L10n.mealTypeUnspecified).tag(MealType?.none)
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(MealType?.some(type))
                }
            }

            TextField(String(localized: L10n.mealDetailNote), text: $viewModel.noteDraft, axis: .vertical)
                .lineLimit(3...8)

            Button(String(localized: L10n.mealDetailSave)) {
                Task { await viewModel.saveMeal() }
            }
        }
    }
}

extension MealType {
    /// 表示名は Presentation の責務。Domain 側には持たせない。
    var displayName: LocalizedStringResource {
        switch self {
        case .breakfast: L10n.mealTypeBreakfast
        case .lunch: L10n.mealTypeLunch
        case .dinner: L10n.mealTypeDinner
        case .snack: L10n.mealTypeSnack
        }
    }
}
