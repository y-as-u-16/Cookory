import SwiftUI

struct MealRowView: View {
    let meal: MealRecord

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(photoID: meal.photoIDs.first)
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.occurredAt, format: .relative(presentation: .named))
                    .font(.body)
                if let note = meal.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }
}
