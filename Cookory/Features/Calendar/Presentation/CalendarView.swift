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
        // List は記録だけを持つ。スワイプ削除が List に依存するため。
        List {
            selectedDaySection
        }
        .listStyle(.plain)
        // カレンダーを行として入れると、区切り線・余白・背景をすべて打ち消す
        // 必要があった。List の外に出せばその打ち消しが要らない。
        .safeAreaInset(edge: .top, spacing: 0) { calendarHeader }
        .navigationTitle(Text(L10n.calendarTitle))
        .navigationBarTitleDisplayMode(.inline)
        // List の行に置くと、行タップがボタンを吸収して個別に反応しない。
        .toolbar { monthNavigation }
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

    private var calendarHeader: some View {
        VStack(spacing: 20) {
            weekdayHeader
            grid
            if let message = viewModel.errorMessage {
                InlineErrorView(message: message)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // 記録の一覧がこの下をスクロールするため、地を敷いて透けを防ぐ。
        .background(.bar)
        // カレンダー部分は List の外にあるため、行の swipeActions とは競合しない。
        .gesture(monthSwipe)
    }

    /// 横に払って月を移す。縦の動きが大きいときは一覧のスクロールとして扱う。
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else { return }
                Task {
                    if horizontal < 0 {
                        await viewModel.showNextMonth()
                    } else {
                        await viewModel.showPreviousMonth()
                    }
                }
            }
    }

    @ToolbarContentBuilder
    private var monthNavigation: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { Task { await viewModel.showPreviousMonth() } } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text(L10n.calendarPreviousMonth))
        }

        ToolbarItem(placement: .principal) {
            Text(viewModel.displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
        }

        // 右端は設定ボタンが使う。月送りは 2 つとも左へ寄せる。
        ToolbarItem(placement: .topBarLeading) {
            Button { Task { await viewModel.showNextMonth() } } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text(L10n.calendarNextMonth))
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
                // 記録の有無は写真というグラフィックでしか示していない。
                // 読み上げには言葉で渡す。
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day, format: .dateTime.month().day()))
                .accessibilityValue(
                    Text(viewModel.summary(for: day)
                        .map { L10n.a11yMealCount($0.mealCount) } ?? L10n.calendarNoRecord)
                )
                .accessibilityAddTraits(
                    viewModel.selectedDate == day ? [.isButton, .isSelected] : [.isButton]
                )
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
