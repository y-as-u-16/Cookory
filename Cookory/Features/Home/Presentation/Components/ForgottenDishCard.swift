import SwiftUI

/// しばらく作っていない料理。写真を添えて思い出す手がかりにする。
struct ForgottenDishCard: View {
    let forgotten: ForgottenDish
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotoImageView(photoID: forgotten.latestPhotoID)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(forgotten.dish.name.value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(L10n.daysSinceLastCooked(forgotten.daysSinceLastCooked))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size)
    }
}
