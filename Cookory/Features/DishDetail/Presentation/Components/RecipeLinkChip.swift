import SwiftUI

/// 追加済みの参考リンク。入力中の URL 欄と見分けがつくよう塗りで示す。
struct RecipeLinkChip: View {
    let link: RecipeLink
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: link.url) {
                Label(link.displayName, systemImage: "link")
                    .font(.footnote)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            // リンク名だけだと、リンク本体と同じ読み上げになり区別がつかない。
            .accessibilityLabel(Text(L10n.recipeLinkRemove(link.displayName)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.chip, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}
