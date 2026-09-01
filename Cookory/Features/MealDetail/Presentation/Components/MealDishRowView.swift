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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recipeFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(L10n.recipeIngredients)
            TextField("", text: $draft.ingredients, axis: .vertical)
                .lineLimit(3...10)
                .textFieldStyle(.roundedBorder)

            fieldLabel(L10n.recipeSteps)
            TextField("", text: $draft.steps, axis: .vertical)
                .lineLimit(3...12)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var linkFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(L10n.recipeLinks)

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
                    .accessibilityLabel(link.displayName)
                }
                .font(.footnote)
            }

            TextField("https://…", text: $draft.linkURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: L10n.recipeLinkName), text: $draft.linkTitle)
                .textFieldStyle(.roundedBorder)

            Button(String(localized: L10n.recipeAddLink), action: onAddLink)
                .font(.footnote)
                .disabled(!draft.canAddLink)
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

    private func fieldLabel(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
