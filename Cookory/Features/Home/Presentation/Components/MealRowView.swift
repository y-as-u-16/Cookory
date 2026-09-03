import SwiftUI

struct MealRowView: View {
    let meal: MealRecord
    var title: String?

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(photoID: meal.photoIDs.first)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title).font(.body.weight(.medium))
                    Text(meal.occurredAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(meal.occurredAt, format: .relative(presentation: .named))
                        .font(.body)
                }
                if let note = meal.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        // 行のどこを押しても開けるようにする。写真と文字の隙間が反応しないと、
        // 狙って突く操作になる。
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
