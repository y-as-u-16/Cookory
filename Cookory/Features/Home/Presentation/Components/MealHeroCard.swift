import SwiftUI

/// 直近の記録を大きく見せるカード。
///
/// 料理名は写真の上ではなく下に置く。写真の明るさは制御できず、
/// アクセシビリティのフォントサイズでは写真からあふれるため。
struct MealHeroCard: View {
    let recent: RecentMeal

    /// 写真は 4:3。手持ちで真上から撮った料理写真に合う比率。
    private static let aspectRatio: CGFloat = 4 / 3
    private static let cornerRadius: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoImageView(photoID: recent.meal.photoIDs.first, size: .hero)
                .aspectRatio(Self.aspectRatio, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if recent.meal.photoIDs.count > 1 {
                        PhotoCountBadge(count: recent.meal.photoIDs.count)
                            .padding(12)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                if let title = recent.title {
                    Text(title).font(.headline)
                }
                Text(recent.meal.occurredAt, format: .relative(presentation: .named))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 写真が複数あることを示す。1 枚のときは出さない。
struct PhotoCountBadge: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "square.on.square")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
