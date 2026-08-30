import SwiftUI

struct ForgottenDishRowView: View {
    let forgotten: ForgottenDish

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(forgotten.dish.name.value)
                    .font(.body.weight(.medium))
                Text(L10n.daysSinceLastCooked(forgotten.daysSinceLastCooked))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
