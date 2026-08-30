import SwiftUI

struct DishHistoryRowView: View {
    let entry: DishHistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PhotoThumbnailView(photoID: entry.photoID)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.log.cookedAt.formatted(date: .numeric, time: .omitted))
                    .font(.subheadline.weight(.medium))
                if let rating = entry.log.rating {
                    RatingView(rating: rating)
                }
                if let note = entry.log.note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

/// 星の表示。DishRating.range を単一の情報源にする。
struct RatingView: View {
    let rating: DishRating

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DishRating.range, id: \.self) { value in
                Image(systemName: value <= rating.value ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("評価 \(rating.value)")
    }
}
