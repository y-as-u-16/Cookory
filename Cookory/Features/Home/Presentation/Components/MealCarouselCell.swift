import SwiftUI

/// 横並びの記録カード。
struct MealCarouselCell: View {
    let recent: RecentMeal
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotoImageView(photoID: recent.meal.photoIDs.first)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(recent.title ?? "")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(recent.meal.occurredAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size)
    }
}
