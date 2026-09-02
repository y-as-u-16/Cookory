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
        .task(id: photoID) { await load() }
    }

    private func load() async {
        guard let photoID, let storage = dependencies?.imageStorage else {
            image = nil
            return
        }
        // 失敗時は nil に戻す。前の写真が残ると別の記録の画像を見せてしまう。
        image = (try? await storage.loadThumbnail(id: photoID)).flatMap { UIImage(data: $0) }
    }
}
