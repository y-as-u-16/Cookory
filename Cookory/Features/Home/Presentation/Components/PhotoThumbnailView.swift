import SwiftUI

/// 写真のサムネイル。読み込みは非同期で、失敗時はプレースホルダを出す。
struct PhotoThumbnailView: View {
    let photoID: UUID?

    /// 既定のサイズ。カレンダーのマスなど小さく出したい場所で上書きする。
    var size: CGFloat = 56

    @Environment(\.dependencies) private var dependencies
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.thumbnail))
        // 写真そのものに意味は無く、隣の文字が中身を伝える。読み上げに残すと
        // 一覧をたどるたび「写真」が繰り返される。
        .accessibilityHidden(true)
        .task(id: photoID) { await load() }
    }

    private func load() async {
        guard let photoID, let storage = dependencies?.imageStorage else {
            image = nil
            return
        }

        if let cached = PhotoImageCache.shared.image(for: photoID, maxDimension: Self.thumbnailDimension) {
            image = cached
            return
        }

        // 失敗時は nil に戻す。前の写真が残ると別の記録の画像を見せてしまう。
        let loaded = (try? await storage.loadThumbnail(id: photoID)).flatMap { UIImage(data: $0) }
        if let loaded {
            PhotoImageCache.shared.store(loaded, for: photoID, maxDimension: Self.thumbnailDimension)
        }
        image = loaded
    }

    /// `LocalImageStorage` がサムネイルを書き出す長辺。鍵を分けるためだけに持つ。
    private static let thumbnailDimension = 400
}
