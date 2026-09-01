import SwiftUI

/// 写真中心の月間カレンダー（APP_DESIGN.md #9）。
struct CalendarView: View {
    @State private var viewModel: CalendarViewModel
    @State private var pendingDeletion: UUID?
    @State private var isConfirmingDelete = false

    private let onSelectMeal: (UUID) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(viewModel: CalendarViewModel, onSelectMeal: @escaping (UUID) -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSelectMeal = onSelectMeal
    }

    var body: some View {
        // List なのはその日の記録をスワイプで消せるようにするため。
        // カレンダー部分は区切り線と余白を外して従来の見た目を保つ。
        List {
            Section {
                VStack(spacing: 20) {
                    monthHeader
                    weekdayHeader
                    grid
                    if let message = viewModel.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            selectedDaySection
        }
        .listStyle(.plain)
        .navigationTitle(Text(L10n.calendarTitle))
        // 詳細画面で削除して戻ったときに反映させるため、表示のたびに取り直す。
        .onAppear { Task { await viewModel.reload() } }
        // confirmationDialog だと iPhone でもリスト先頭を起点に吹き出してしまう。
        // alert は位置を持たないため、どの行から消しても同じ見え方になる。
        .alert(
            Text(L10n.mealDetailDeleteConfirm),
            isPresented: $isConfirmingDelete,
            presenting: pendingDeletion
        ) { mealID in
            Button(String(localized: L10n.commonCancel), role: .cancel) {
                pendingDeletion = nil
            }
            Button(String(localized: L10n.mealDetailDelete), role: .destructive) {
                pendingDeletion = nil
                Task { await viewModel.delete(mealID: mealID) }
            }
        } message: { _ in
            Text(L10n.mealDetailDeleteMessage)
        }
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
            Section {
                if viewModel.selectedDayMeals.isEmpty {
                    Text(L10n.calendarNoRecord)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.selectedDayMeals) { meal in
                        Button { onSelectMeal(meal.id) } label: {
                            MealRowView(meal: meal)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        // 端まで払っただけで消えると事故になる。確認を必ず通す。
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = meal.id
                                isConfirmingDelete = true
                            } label: {
                                Label(L10n.mealDetailDelete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}
