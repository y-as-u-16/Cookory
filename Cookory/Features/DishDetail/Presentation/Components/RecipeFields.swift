import SwiftUI

/// 材料と手順の入力。料理詳細画面の Form に置く。
///
/// 見出しは Section のヘッダーとしてカードの外に出す。カードの中に
/// 入れると、見出しと書いた内容の区別がつかない。
struct RecipeContentFields: View {
    @Bindable var draft: DishRecipeDraft

    var body: some View {
        Section(String(localized: L10n.recipeIngredients)) {
            TextField("", text: $draft.ingredients, axis: .vertical)
                .lineLimit(4...12)
        }

        Section(String(localized: L10n.recipeSteps)) {
            TextField("", text: $draft.steps, axis: .vertical)
                .lineLimit(4...16)
        }
    }
}

/// 参考リンクの一覧と追加欄。
struct RecipeLinkFields: View {
    @Bindable var draft: DishRecipeDraft

    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        Section(String(localized: L10n.recipeLinks)) {
            ForEach(draft.links) { link in
                HStack {
                    Link(destination: link.url) {
                        Label(link.displayName, systemImage: "link").lineLimit(1)
                    }
                    Spacer()
                    Button {
                        onRemove(link.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n.recipeLinkRemove(link.displayName)))
                }
            }

            TextField("https://…", text: $draft.linkURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)

            Button(String(localized: L10n.recipeAddLink), action: onAdd)
                .disabled(!draft.canAddLink)
        }
    }
}

/// 記録画面で Section の見た目を再現する器。
///
/// 記録画面のレシピ欄は List の 1 行の中に展開するため Section を置けない。
/// 見出しを外に出し、中身を白いカードに載せる形だけ同じにする。
struct RecipeFieldCard<Content: View>: View {
    let label: LocalizedStringResource

    /// 書き始めの取っ掛かりになる記入例。見出しの横に小さく添える。
    var example: LocalizedStringResource?

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.footnote)
                if let example { Text(example).font(.caption2) }
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 4)

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 記録画面ではこのカードが白い行の上に載る。同じ白だと
                // 境界が消えるため、一段沈めて入力欄だと分かるようにする。
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(Color(.systemGroupedBackground))
                )
        }
    }
}
