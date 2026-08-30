import SwiftUI

/// 記録が 1 件も無いときに出す枠。
///
/// 架空の料理を描かない。個人の記録アプリで偽の履歴を見せると、
/// 自分の記録との区別がつかない。枠の形だけを薄く示す。
struct GhostMealCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(.quaternary).frame(width: 140, height: 14)
                Capsule().fill(.quaternary).frame(width: 90, height: 12)
            }
        }
        .opacity(0.6)
    }
}
