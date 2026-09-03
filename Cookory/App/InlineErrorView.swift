import SwiftUI

/// 画面内に出すエラー。
///
/// 色だけで異常を示さない（WCAG 1.4.1）。赤が見分けられない利用者にも
/// アイコンで伝わるようにする。
struct InlineErrorView: View {
    let message: LocalizedStringResource

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.footnote)
        .foregroundStyle(.red)
    }
}
