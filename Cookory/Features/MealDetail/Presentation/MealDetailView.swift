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
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(
            "この記録を削除しますか？", isPresented: $isConfirmingDelete, titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { if await viewModel.deleteMeal() { onDeleted() } }
            }
        } message: {
            Text("写真と料理の履歴もあわせて削除されます。")
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
                Button("この記録を削除", role: .destructive) { isConfirmingDelete = true }
            }
        }
    }

    private func photoSection(_ detail: MealDetail) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(detail.meal.photoIDs, id: \.self) { photoID in
                        PhotoThumbnailView(photoID: photoID, size: 160)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(detail.meal.occurredAt.formatted(date: .long, time: .shortened))
        }
    }

    private func dishSection(_ detail: MealDetail) -> some View {
        Section("作った料理") {
            ForEach(detail.dishes) { entry in
                Button { onSelectDish(entry.dish.id) } label: {
                    MealDishRowView(entry: entry)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                TextField("料理名を追加", text: $viewModel.dishNameDraft)
                    .submitLabel(.done)
                    .onSubmit { Task { await viewModel.addDish() } }
                Button("追加") {
                    Task { await viewModel.addDish() }
                }
                .disabled(!viewModel.canAddDish)
            }
        }
    }

    private func noteSection(_ detail: MealDetail) -> some View {
        Section("この日のこと") {
            Picker("食事の種類", selection: $viewModel.mealTypeDraft) {
                Text("指定なし").tag(MealType?.none)
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(MealType?.some(type))
                }
            }

            TextField("メモ", text: $viewModel.noteDraft, axis: .vertical)
                .lineLimit(3...8)

            Button("保存") {
                Task { await viewModel.saveMeal() }
            }
        }
    }
}

extension MealType {
    /// 表示名は Presentation の責務。Domain 側には持たせない。
    var displayName: String {
        switch self {
        case .breakfast: "朝食"
        case .lunch: "昼食"
        case .dinner: "夕食"
        case .snack: "軽食"
        }
    }
}
