import PhotosUI
import SwiftUI

/// 写真を選んで記録する画面。アプリで最も重要な画面（APP_DESIGN.md #8）。
///
/// 選択した時点で保存する。確認ボタンを挟まないのは
/// 「Record Now, Organize Later」の実装（APP_DESIGN.md #4.3）。
struct CaptureView: View {
    /// 1 回の食卓で選べる枚数の上限。画像の保存が直列なため、
    /// 多すぎると待ち時間が体感できるほど伸びる。
    static let photoLimit = 10

    @State private var viewModel: CaptureViewModel
    @State private var selection: [PhotosPickerItem] = []

    private let onSaved: (UUID) -> Void

    init(viewModel: CaptureViewModel, onSaved: @escaping (UUID) -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 24) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("記録する")
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            picker
        case .saving:
            ProgressView("保存しています")
        case .saved(let meal):
            SavedConfirmationView(
                photoCount: meal.photoIDs.count,
                onAddDetails: { onSaved(meal.id) },
                onDone: reset
            )
        case .failed(let message):
            FailureView(message: message, onRetry: reset)
        }
    }

    private var picker: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selection,
                maxSelectionCount: Self.photoLimit,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("写真を選ぶ", systemImage: "photo.on.rectangle.angled")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

            Text("最大 \(Self.photoLimit) 枚まで選べます")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            images.append(data)
        }

        guard !images.isEmpty else {
            selection = []
            return
        }

        await viewModel.save(images: images)
        selection = []
    }

    private func reset() {
        selection = []
        viewModel.reset()
    }
}
