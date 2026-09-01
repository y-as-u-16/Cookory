import SwiftUI

/// 記録に紐づく料理 1 品。タップでレシピ欄が開く。
///
/// 別画面に飛ばさないのは、料理名を書いた直後に作り方まで
/// 書き切れるようにするため。
struct MealDishRowView: View {
    let entry: MealDishEntry
    let isExpanded: Bool
    @Bindable var draft: DishRecipeDraft

    let onToggle: () -> Void
    let onSaveRecipe: () -> Void
    let onAddLink: () -> Void
    let onRemoveLink: (UUID) -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                recipeFields
                linkFields
                actions
            }
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.dish.name.value).font(.body)
                    if let note = entry.log.note {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let rating = entry.log.rating {
                    RatingView(rating: rating)
                }
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            // 行のどこを押しても開く。文字とシェブロンの隙間が反応しないと、
            // 狙って突く操作になる。
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recipeFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                RecipeFieldLabel(text: L10n.recipeIngredients)
                TextField(String(localized: L10n.recipeIngredientsPlaceholder),
                          text: $draft.ingredients, axis: .vertical)
                    .lineLimit(3...10)
                    .recipeFieldBackground()
            }

            VStack(alignment: .leading, spacing: 6) {
                RecipeFieldLabel(text: L10n.recipeSteps)
                TextField(String(localized: L10n.recipeStepsPlaceholder),
                          text: $draft.steps, axis: .vertical)
                    .lineLimit(3...12)
                    .recipeFieldBackground()
            }
        }
    }

    private var linkFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            RecipeFieldLabel(text: L10n.recipeLinks)

            ForEach(draft.links) { link in
                RecipeLinkChip(link: link) { onRemoveLink(link.id) }
            }

            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    TextField("https://…", text: $draft.linkURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .recipeFieldBackground()
                    TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)
                        .recipeFieldBackground()
                }

                Button(action: onAddLink) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(!draft.canAddLink)
                .accessibilityLabel(Text(L10n.recipeAddLink))
            }
        }
    }

    private var actions: some View {
        HStack {
            Button(String(localized: L10n.recipeSave), action: onSaveRecipe)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
            Button(String(localized: L10n.mealDetailOpenDish), action: onOpenHistory)
                .font(.footnote)
        }
    }
}
