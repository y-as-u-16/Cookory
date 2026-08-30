import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 共有シートへ渡す画像。
///
/// Transferable にすることで ShareLink がそのまま扱える。
/// 一時ファイルを作らずメモリ上のデータを渡す。
struct ShareImage: Transferable, Equatable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("Cookory.png")
    }
}
