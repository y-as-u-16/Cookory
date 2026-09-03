import PhotosUI
import SwiftUI

/// レシピに貼ったスクリーンショット。
///
/// Web やアプリで見つけたレシピを文字に起こし直さず残せるようにする。
/// リンクだけだと、リンク先が消えたときに手元に何も残らない。
struct RecipePhotoStrip: View {
    /// 一度に貼れる枚数の上限。記録の写真と揃える。
    static let limit = 10

    let photoIDs: [UUID]
    let onAdd: ([Data]) -> Void
    let onRemove: (UUID) -> Void

    @State private var selection: [PhotosPickerItem] = []
    @State private var zoomed: ZoomedPhoto?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photoIDs, id: \.self) { photoID in
                    thumbnail(photoID)
                }
                addButton
            }
            .padding(.vertical, 4)
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .fullScreenCover(item: $zoomed) { target in
            RecipePhotoViewer(photoID: target.id) { zoomed = nil }
        }
    }

    private func thumbnail(_ photoID: UUID) -> some View {
        Button {
            zoomed = ZoomedPhoto(id: photoID)
        } label: {
            PhotoImageView(photoID: photoID, size: .thumbnail)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.thumbnail, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button {
                onRemove(photoID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    // 既定のままだと 17pt 程度。隣のサムネイルと 8pt しか
                    // 離れておらず、誤タップで写真が消える。
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
            .accessibilityLabel(Text(L10n.recipePhotoRemove))
        }
    }

    private var addButton: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: Self.limit,
            matching: .images,
            photoLibrary: .shared()
        ) {
            RoundedRectangle(cornerRadius: CornerRadius.thumbnail, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.tertiary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
        .accessibilityLabel(Text(L10n.recipePhotoAdd))
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            images.append(data)
        }
        selection = []
        onAdd(images)
    }
}

/// fullScreenCover(item:) に渡すための包み。UUID をそのまま
/// Identifiable にすると、アプリ全体の UUID に影響が及ぶ。
private struct ZoomedPhoto: Identifiable {
    let id: UUID
}

/// 貼ったスクリーンショットを読める大きさで見る。
///
/// レシピのスクショは文字が主役なので、拡大できないと用を成さない。
private struct RecipePhotoViewer: View {
    let photoID: UUID
    let onClose: () -> Void

    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PhotoImageView(photoID: photoID, size: .hero)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = max(1, $0.magnification) }
                        .onEnded { _ in withAnimation(.snappy) { scale = max(1, scale) } }
                )
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .padding()
            .accessibilityLabel(Text(L10n.commonCancel))
        }
    }
}
