import SwiftUI

/// 記録に紐づく料理 1 品。タップでレシピ欄が開く。
///
/// 別画面に飛ばさないのは、料理名を書いた直後に作り方まで
/// 書き切れるようにするため。保存は画面下部の 1 つに集約する。
struct MealDishRowView: View {
    let entry: MealDishEntry
    let isExpanded: Bool
    @Bindable var draft: DishRecipeDraft
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
                VStack(alignment: .leading, spacing: 20) {
                    field(L10n.recipeIngredients, example: L10n.recipeIngredientsExample) {
                        TextField("", text: $draft.ingredients, axis: .vertical)
                            .lineLimit(3...10)
                            .focused($isEditingText)
                    }

                    field(L10n.recipeSteps, example: L10n.recipeStepsExample) {
                        TextField("", text: $draft.steps, axis: .vertical)
                            .lineLimit(3...12)
                            .focused($isEditingText)
                    }

                    field(L10n.recipePhotos, example: nil) {
                        RecipePhotoStrip(
                            photoIDs: draft.photoIDs,
                            onAdd: onAddPhotos,
                            onRemove: onRemovePhoto
                        )
                    }

                    linkField
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

    private var linkField: some View {
        field(L10n.recipeLinks, example: nil) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(draft.links) { link in
                    RecipeLinkChip(link: link) { onRemoveLink(link.id) }
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(String(localized: L10n.recipeLinkURL), text: $draft.linkURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($isEditingText)
                        Divider()
                        TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)
                            .focused($isEditingText)
                    }

                    Button(action: onAddLink) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!draft.canAddLink)
                    .accessibilityLabel(Text(L10n.recipeAddLink))
                }
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

    /// 見出しと中身を組にする。見出しは小さく添えるだけにして、
    /// 入力そのものに視線が向くようにする。
    private func field(
        _ label: LocalizedStringResource,
        example: LocalizedStringResource?,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.caption.weight(.semibold))
                // 記入例は見出しの横に置く。入力欄の中に置くと、書いてある
                // 内容との区別がつかない。
                if let example { Text(example).font(.caption2) }
            }
            .foregroundStyle(.secondary)
            content()
        }
    }
}
