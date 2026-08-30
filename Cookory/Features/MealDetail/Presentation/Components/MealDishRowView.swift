import SwiftUI

struct MealDishRowView: View {
    let entry: MealDishEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.dish.name.value).font(.body)
                Spacer()
                if let rating = entry.log.rating {
                    RatingView(rating: rating)
                }
            }
            if let note = entry.log.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
