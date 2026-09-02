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
            // 記録の無い日には何も置かない。目印を出すと、記録が少ないうちは
            // ほぼ全日に付いて「何かある日」に見えてしまう。
            if let summary {
                PhotoThumbnailView(photoID: summary.thumbnailID, size: 32)
                    .overlay(alignment: .topTrailing) {
                        // 2 件以上ある日だけ件数を出す。1 件のときは写真だけで足りる。
                        if summary.mealCount > 1 {
                            Text("\(summary.mealCount)")
                                .font(.caption2.weight(.bold))
                                .padding(3)
                                .background(.thinMaterial, in: Circle())
                        }
                    }
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: CornerRadius.thumbnail))
    }
}
