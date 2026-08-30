import SwiftUI

/// 写真中心の月間カレンダー（APP_DESIGN.md #9）。
struct CalendarView: View {
    @State private var viewModel: CalendarViewModel
    private let onSelectMeal: (UUID) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(viewModel: CalendarViewModel, onSelectMeal: @escaping (UUID) -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSelectMeal = onSelectMeal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                weekdayHeader
                grid
                if let message = viewModel.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                selectedDaySection
            }
            .padding()
        }
        .navigationTitle("カレンダー")
        .task { await viewModel.load() }
    }

    private var monthHeader: some View {
        HStack {
            Button { Task { await viewModel.showPreviousMonth() } } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(viewModel.displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
            Spacer()
            Button { Task { await viewModel.showNextMonth() } } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Self.columns, spacing: 0) {
            ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                Text(symbol).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: 8) {
            // 月初を正しい曜日の位置から始める。
            ForEach(0..<viewModel.leadingBlankCount, id: \.self) { _ in
                Color.clear.frame(height: 56)
            }
            ForEach(viewModel.daysInDisplayedMonth, id: \.self) { day in
                Button {
                    Task { await viewModel.select(day) }
                } label: {
                    CalendarDayCell(
                        date: day,
                        summary: viewModel.summary(for: day),
                        isSelected: viewModel.selectedDate == day
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        if viewModel.selectedDate != nil {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.selectedDayMeals.isEmpty {
                    Text("この日の記録はありません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.selectedDayMeals) { meal in
                        Button { onSelectMeal(meal.id) } label: {
                            MealRowView(meal: meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
