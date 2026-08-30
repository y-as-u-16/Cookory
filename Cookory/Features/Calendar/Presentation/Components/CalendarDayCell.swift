import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let summary: CalendarDaySummary?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date, format: .dateTime.day())
                .font(.caption2)
                .foregroundStyle(summary == nil ? .secondary : .primary)
            if let summary {
                PhotoThumbnailView(photoID: summary.thumbnailID, size: 32)
                    .overlay(alignment: .topTrailing) {
                        // 2 件以上ある日だけ件数を出す。1 件のときは写真だけで足りる。
                        if summary.mealCount > 1 {
                            Text("\(summary.mealCount)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(3)
                                .background(.thinMaterial, in: Circle())
                        }
                    }
            } else {
                Circle().fill(.quaternary).frame(width: 6, height: 6)
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }
}
