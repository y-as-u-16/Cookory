import SwiftUI

/// 写真の表示。用途に応じた解像度で読む。
///
/// すべてをサムネイル（400px）で読むと大きく出す場所で粗くなり、
/// すべてを原本（2048px）で読むと小さな一覧でデコードが重い。
struct PhotoImageView: View {
    enum Size {
        /// 一覧の小さなサムネイル。
        case thumbnail
        /// 画面幅いっぱいに近い大きさ。
        case hero

        /// 読み出す長辺の画素数。Retina を考慮して表示 pt の 3 倍を目安にする。
        var maxDimension: Int {
            switch self {
            case .thumbnail: 400
            case .hero: 1200
            }
        }
    }

    let photoID: UUID?
    var size: Size = .thumbnail

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
        .clipped()
        .task(id: photoID) { await load() }
        // 画面外に出たら解放する。持ち続けると一覧をたどるほどメモリが増える。
        .onDisappear { image = nil }
    }

    private func load() async {
        guard let photoID, let storage = dependencies?.imageStorage else { return }

        let data: Data?
        switch size {
        case .thumbnail:
            data = try? await storage.loadThumbnail(id: photoID)
        case .hero:
            data = try? await storage.loadDisplayImage(
                id: photoID, maxDimension: size.maxDimension
            )
        }

        guard let data else { return }
        image = UIImage(data: data)
    }
}
