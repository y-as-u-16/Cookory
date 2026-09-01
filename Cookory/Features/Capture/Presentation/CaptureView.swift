import PhotosUI
import SwiftUI

/// 写真を選んで記録する画面。アプリで最も重要な画面（APP_DESIGN.md #8）。
///
/// 選択した時点で保存する。確認ボタンを挟まないのは
/// 「Record Now, Organize Later」の実装（APP_DESIGN.md #4.3）。
/// 保存できたら料理名とレシピの入力画面へそのまま進む。
struct CaptureView: View {
    /// 1 回の食卓で扱える枚数の上限。撮影と選択で揃える。
    /// 画像の保存が直列なため、多すぎると待ち時間が体感できるほど伸びる。
    static let photoLimit = 10

    @State private var viewModel: CaptureViewModel
    @State private var selection: [PhotosPickerItem] = []
    @State private var isShowingCamera = false

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
        .navigationTitle(Text(L10n.captureTitle))
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        // 保存が終わったら入力画面へ送る。確認画面を挟むと
        // 「あとで書く」が既定になり、料理名が付かない記録が溜まる。
        .onChange(of: viewModel.savedRecord?.id) { _, id in
            guard let id else { return }
            selection = []
            viewModel.reset()
            onSaved(id)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            MultiPhotoCameraView(
                limit: Self.photoLimit,
                onFinish: { images in
                    isShowingCamera = false
                    guard !images.isEmpty else { return }
                    Task { await viewModel.save(images: images) }
                },
                onCancel: { isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .saved:
            picker
        case .saving:
            ProgressView { Text(L10n.captureSaving) }
        case .failed(let message):
            FailureView(message: message, onRetry: reset)
        }
    }

    private var picker: some View {
        VStack(spacing: 12) {
            // シミュレータではカメラが無いため出さない。
            if CameraSession.isAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(L10n.captureTakePhoto, systemImage: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
            }

            PhotosPicker(
                selection: $selection,
                maxSelectionCount: Self.photoLimit,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(L10n.captureChoosePhoto, systemImage: "photo.on.rectangle.angled")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            // カメラがあるときは撮影を主役にし、選択は控えめにする。
            .buttonStyle(.bordered)

            Text(L10n.capturePhotoLimit(Self.photoLimit))
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
    }

    private func reset() {
        selection = []
        viewModel.reset()
    }
}
