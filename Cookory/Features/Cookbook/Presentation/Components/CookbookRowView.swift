import SwiftUI

struct CookbookRowView: View {
    let item: CookbookItem

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(photoID: item.latestPhotoID)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.dish.name.value).font(.body.weight(.medium))
                    if item.dish.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                }
                if let lastCookedAt = item.lastCookedAt {
                    Text(lastCookedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(L10n.cookCount(item.cookCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        // まとめないと 1 行に到達するのに 5 回スワイプが要る。
        .accessibilityElement(children: .combine)
    }
}
