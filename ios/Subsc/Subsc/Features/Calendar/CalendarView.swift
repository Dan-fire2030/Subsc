import SwiftData
import SwiftUI

/// 月のかたちで「いつ、いくら出ていくのか」を見る画面です。
///
/// **読むための画面です。** ここから費目を足したり金額を直したりはしません
/// （追加はホームの「＋」、実績の入力は既存の画面へ渡します）。
/// 入口を散らすと、どこから足したかで挙動が違うのではという疑いが生まれます。
///
/// ## 月送りに横スクロールを使っていない理由
///
/// **`ScrollView(.horizontal)` + `LazyHStack` + `containerRelativeFrame`
/// + `.scrollTargetBehavior(.paging)` は使ってはいけません。**
/// レイアウトが毎フレーム回り続け、CPUが100%に張り付いて操作を受け付けなくなります
/// （2026-08-08にチュートリアルで踏んだ。`.spec/KNOWLEDGE.md`）。
/// ここでは月を1枚だけ描き、前後の移動はボタンと横方向のドラッグで行います。
struct CalendarView: View {
    @Environment(CalendarDisplayStore.self) private var display
    @Query(sort: \Subscription.renewalDate) private var subscriptions: [Subscription]
    @Query(sort: \Loan.createdAt) private var loans: [Loan]

    /// 表示中の月です。日付そのものではなく「その月のどこか」を指します。
    @State private var cursor = Date.now
    /// 選んだ日（`startOfDay`）です。
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var amountEditor: AmountEditorTarget?
    @State private var isChoosingMonth = false

    private var calendar: Calendar { .current }

    /// ホイールに出す年です。**登録されている期日に追従させます。**
    private var selectableYears: [Int] {
        CalendarMonthPickerRange.years(
            from: subscriptions.map(\.renewalDate) + loans.compactMap {
                LoanSummary.make(for: $0).nextDueDate
            },
            calendar: calendar
        )
    }

    private var days: [CalendarDay] {
        CalendarMonthBuilder.days(
            inMonthOf: cursor,
            subscriptions: subscriptions,
            loans: loans,
            calendar: calendar
        )
    }

    private var selectedDay: CalendarDay? {
        days.first { $0.date == selectedDate }
    }

    /// 表示中の月が今日を含むか。**離れているときだけ**戻る手段を出します。
    private var isShowingCurrentMonth: Bool {
        calendar.isDate(cursor, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BlackCatSpacing.l) {
                    monthHeader

                    CalendarMonthGrid(
                        days: days,
                        selectedDate: selectedDate,
                        showsAmounts: display.showsAmounts,
                        calendar: calendar,
                        onSelect: { selectedDate = $0 }
                    )
                    // **縦スクロールを殺さないよう `simultaneousGesture` にします。**
                    // 専有すると一覧まで下ろせなくなります。
                    .simultaneousGesture(monthSwipe)

                    CalendarDayList(day: selectedDay, onSelectUnentered: presentAmountEditor)
                }
                .padding(.horizontal, BlackCatSpacing.l)
                .padding(.bottom, BlackCatSpacing.xxl)
            }
            .liquidGlassScreen()
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CalendarDisplayToggle(showsAmounts: display.showsAmounts) {
                        @Bindable var display = display
                        display.showsAmounts.toggle()
                    }
                }
            }
            .sheet(item: $amountEditor) { target in
                AmountEntryEditorView(
                    subscription: target.subscription,
                    periodKey: target.periodKey
                )
            }
            .sheet(isPresented: $isChoosingMonth) {
                CalendarMonthPicker(
                    initialYear: calendar.component(.year, from: cursor),
                    initialMonth: calendar.component(.month, from: cursor),
                    years: selectableYears,
                    calendar: calendar,
                    onSelect: showMonth
                )
            }
        }
    }

    // MARK: - 月の見出しと移動

    private var monthHeader: some View {
        HStack(spacing: BlackCatSpacing.s) {
            // **見出しそのものを押せるようにします（2026-08-11）。**
            // 矢印だけだと遠い月へ行くのに何度も押す必要がありました。
            // 押せることが見た目で分かるよう、山形を添えています。
            Button {
                isChoosingMonth = true
            } label: {
                HStack(spacing: 4) {
                    Text(cursor.formatted(.dateTime.year().month()))
                        .font(BlackCatType.title)
                        .foregroundStyle(BlackCatPalette.text)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BlackCatPalette.textMuted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("年月を選ぶ")
            .accessibilityValue(cursor.formatted(.dateTime.year().month()))
            .accessibilityIdentifier("calendar-month-header")

            if !isShowingCurrentMonth {
                Button("今日") { goToToday() }
                    .font(BlackCatType.label)
                    .foregroundStyle(BlackCatPalette.accent)
                    .frame(minHeight: 44)
            }

            Spacer(minLength: 0)

            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel("前の月")

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(BlackCatPalette.textMuted)
    }

    /// 横へ払って月を送ります。**縦の動きのほうが大きいときは無視します。**
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else { return }
                shiftMonth(by: horizontal < 0 ? 1 : -1)
            }
    }

    private func shiftMonth(by value: Int) {
        guard let moved = calendar.date(byAdding: .month, value: value, to: cursor) else { return }
        cursor = moved
        // **移動先の月にも選択を残します。** 選択が消えると下の一覧が空になり、
        // 何を見ていたのか分からなくなります。同じ日が無い月は末日へ寄せます。
        selectedDate = clampedSelection(in: moved)
    }

    /// ホイールで選ばれた年月へ飛びます。
    ///
    /// **選択日の扱いは `shiftMonth` と同じ**にします。矢印で動いたときと
    /// ホイールで飛んだときで挙動が違うと、同じ「月を変える」操作の結果が読めません。
    private func showMonth(year: Int, month: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let moved = calendar.date(from: components) else { return }
        cursor = moved
        selectedDate = clampedSelection(in: moved)
    }

    private func goToToday() {
        cursor = .now
        selectedDate = calendar.startOfDay(for: .now)
    }

    /// 選んでいた日を移動先の月へ移します。31日を選んだまま2月へ行くと消えるためです。
    private func clampedSelection(in month: Date) -> Date {
        let day = calendar.component(.day, from: selectedDate)
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return month }
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = min(day, range.upperBound - 1)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? month
    }

    private func presentAmountEditor(for clientID: String) {
        guard let subscription = subscriptions.first(where: { $0.clientID == clientID }) else {
            return
        }
        amountEditor = AmountEditorTarget(
            subscription: subscription,
            periodKey: AmountEntry.periodKey(for: selectedDate, calendar: calendar)
        )
    }
}

/// 実績入力のシートへ渡す対象です。
struct AmountEditorTarget: Identifiable {
    let id = UUID()
    let subscription: Subscription
    let periodKey: Int
}
