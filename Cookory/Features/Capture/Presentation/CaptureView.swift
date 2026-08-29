import PhotosUI
import SwiftUI

/// 写真を選んで記録する画面。アプリで最も重要な画面（APP_DESIGN.md #8）。
///
/// 選択した時点で保存する。確認ボタンを挟まないのは
/// 「Record Now, Organize Later」の実装（APP_DESIGN.md #4.3）。
struct CaptureView: View {
    @State private var viewModel: CaptureViewModel
    @State private var selection: PhotosPickerItem?

    init(viewModel: CaptureViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("記録する")
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            picker
        case .saving:
            ProgressView("保存しています")
        case .saved:
            SavedConfirmationView(onDone: reset)
        case .failed(let message):
            FailureView(message: message, onRetry: reset)
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Label("写真を選ぶ", systemImage: "camera.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            selection = nil
            return
        }
        await viewModel.save(image: data)
        selection = nil
    }

    private func reset() {
        selection = nil
        viewModel.reset()
    }
}
