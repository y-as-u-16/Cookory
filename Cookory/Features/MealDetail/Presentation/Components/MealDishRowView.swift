import SwiftUI

/// 記録に紐づく料理 1 品。タップでレシピ欄が開く。
///
/// 別画面に飛ばさないのは、料理名を書いた直後に作り方まで
/// 書き切れるようにするため。保存は画面下部の 1 つに集約する。
struct MealDishRowView: View {
    let entry: MealDishEntry
    let isExpanded: Bool
    @Bindable var draft: DishRecipeDraft
    @Binding var name: String
    @FocusState.Binding var isEditingText: Bool

    let onToggle: () -> Void
    let onAddLink: () -> Void
    let onRemoveLink: (UUID) -> Void
    let onAddPhotos: ([Data]) -> Void
    let onRemovePhoto: (UUID) -> Void
    let onOpenHistory: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                // 作り方画面と同じ「見出しはカードの外、中身は白いカード」に
                // 揃える。List の行の中なので Section は使えず、器だけ再現する。
                VStack(alignment: .leading, spacing: 16) {
                    // 打ち間違えた名前をここで直せるようにする。図鑑や過去の
                    // 記録に出る名前もまとめて変わる。
                    RecipeFieldCard(label: L10n.mealDetailDishName) {
                        TextField("", text: $name)
                            .focused($isEditingText)
                    }

                    RecipeFieldCard(
                        label: L10n.recipeIngredients,
                        example: L10n.recipeIngredientsExample
                    ) {
                        TextField("", text: $draft.ingredients, axis: .vertical)
                            .lineLimit(3...10)
                            .focused($isEditingText)
                    }

                    RecipeFieldCard(
                        label: L10n.recipeSteps,
                        example: L10n.recipeStepsExample
                    ) {
                        TextField("", text: $draft.steps, axis: .vertical)
                            .lineLimit(3...12)
                            .focused($isEditingText)
                    }

                    RecipeFieldCard(label: L10n.recipePhotos) {
                        RecipePhotoStrip(
                            photoIDs: draft.photoIDs,
                            onAdd: onAddPhotos,
                            onRemove: onRemovePhoto
                        )
                    }

                    linkCard
                    historyLink
                }
                .padding(.top, 16)
            }
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        Button(action: onToggle) {
            headerLayout
                // 行のどこを押しても開く。文字とシェブロンの隙間が反応しないと、
                // 狙って突く操作になる。
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        // 開いているかを値として渡す。ヒントは VoiceOver 設定で切れるため、
        // 状態はそれとは別の経路でも伝える。
        .accessibilityValue(Text(isExpanded ? L10n.a11yExpanded : L10n.a11yCollapsed))
        .accessibilityHint(Text(isExpanded ? L10n.a11yCollapseRecipe : L10n.a11yExpandRecipe))
    }

    @ViewBuilder
    private var headerLayout: some View {
        // 大きな文字では横に並べきれず、料理名が 1 文字ずつ折り返す。
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                title
                HStack(spacing: 8) {
                    if let rating = entry.log.rating { RatingView(rating: rating) }
                    Spacer()
                    chevron
                }
            }
        } else {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 8)
                if let rating = entry.log.rating { RatingView(rating: rating) }
                chevron
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.dish.name.value)
                .font(.body.weight(isExpanded ? .semibold : .regular))
                .foregroundStyle(.primary)
            if let note = entry.log.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            // 閉じても中身があることが分かるようにする。畳んだだけで
            // 「消えた」と受け取られないため。
            if !isExpanded, draft.hasContent {
                Label(L10n.mealDetailRecipeFilled, systemImage: "text.alignleft")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            // 回転で開閉を示す。別アイコンに差し替えるより位置が安定する。
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }

    /// 参考リンク。作り方画面の Section と同じく、欄ごとに区切り線を挟む。
    private var linkCard: some View {
        RecipeFieldCard(label: L10n.recipeLinks) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(draft.links) { link in
                    HStack {
                        Link(destination: link.url) {
                            Label(link.displayName, systemImage: "link").lineLimit(1)
                        }
                        Spacer()
                        Button {
                            onRemoveLink(link.id)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(L10n.recipeLinkRemove(link.displayName)))
                    }
                    .padding(.vertical, 10)
                    Divider()
                }

                TextField("https://…", text: $draft.linkURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($isEditingText)
                    .padding(.vertical, 10)

                Divider()

                TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)
                    .focused($isEditingText)
                    .padding(.vertical, 10)

                Divider()

                Button(String(localized: L10n.recipeAddLink), action: onAddLink)
                    .disabled(!draft.canAddLink)
                    .padding(.vertical, 10)
            }
        }
    }

    private var historyLink: some View {
        Button(action: onOpenHistory) {
            HStack(spacing: 4) {
                Text(L10n.mealDetailOpenDish)
                Image(systemName: "arrow.right")
            }
            .font(.footnote)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
}
