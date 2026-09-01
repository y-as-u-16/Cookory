import SwiftUI

/// レシピの入力欄の見た目。
///
/// `.roundedBorder` は枠線だけで背景が抜けるため、カードの上に置くと
/// 浮いて見える。塗りを敷いて周囲との段差を作る。
struct RecipeFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func recipeFieldBackground() -> some View {
        modifier(RecipeFieldBackground())
    }
}

/// 入力欄の見出し。本文より小さく、控えめに置く。
struct RecipeFieldLabel: View {
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

/// 追加済みの参考リンク。入力欄と見分けがつくよう塗りで示す。
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
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}
