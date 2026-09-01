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
            .accessibilityLabel(link.displayName)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}
