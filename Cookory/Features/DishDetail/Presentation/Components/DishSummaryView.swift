import SwiftUI

struct DishSummaryView: View {
    let history: DishHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoThumbnailView(photoID: history.latestPhotoID, size: 200)
                .frame(maxWidth: .infinity)
            Text(L10n.dishCookCount(history.cookCount))
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("dishCookCount")
            if let lastCookedAt = history.lastCookedAt {
                Text(L10n.dishLastCooked(lastCookedAt.formatted(date: .numeric, time: .omitted)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
