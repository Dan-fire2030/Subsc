import SwiftUI

/// 年月を選ぶホイールに出す**年の範囲**を決めます。
///
/// **固定の範囲にしません。** 2000〜2100のような枠を出すと、
/// 中身の無い年をほとんど回すことになり、選ぶ手段としての速さが失われます。
enum CalendarMonthPickerRange {
    /// 端に着いたときに行き止まりに見えないよう、前後へ足す年数です。
    private static let headroom = 1

    /// 登録されている期日から、選べる年を組み立てます。
    ///
    /// **今年は必ず含めます。** 過去の登録しか無いときに今年が抜けると、
    /// 「今日へ戻る」で行ける月をホイールから選べなくなります。
    static func years(
        from dates: [Date],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Int] {
        let thisYear = calendar.component(.year, from: now)
        let years = dates.map { calendar.component(.year, from: $0) }

        let lowest = min(years.min() ?? thisYear, thisYear) - headroom
        let highest = max(years.max() ?? thisYear, thisYear) + headroom

        return Array(lowest...highest)
    }
}

/// 年と月を2列のホイールで選ぶシートです。
///
/// **矢印ボタンと横スワイプは残しています。** 隣の月へ動くだけなら今までのほうが速く、
/// これは「遠くへ一発で飛ぶ」ための手段です。
struct CalendarMonthPicker: View {
    let years: [Int]
    let calendar: Calendar
    /// 選び終えたときに呼ばれます。年と月を渡します。
    let onSelect: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var month: Int

    init(
        initialYear: Int,
        initialMonth: Int,
        years: [Int],
        calendar: Calendar,
        onSelect: @escaping (Int, Int) -> Void
    ) {
        self.years = years
        self.calendar = calendar
        self.onSelect = onSelect
        _year = State(initialValue: initialYear)
        _month = State(initialValue: initialMonth)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("年", selection: $year) {
                    ForEach(years, id: \.self) { year in
                        Text(verbatim: "\(year)年").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("calendar-year-picker")

                Picker("月", selection: $month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(verbatim: "\(month)月").tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("calendar-month-picker")
            }
            .liquidGlassScreen()
            .navigationTitle("年月を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("表示") {
                        onSelect(year, month)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        // **高さを内容に合わせます。** 全画面で出すとカレンダーが完全に隠れ、
        // どの月から動かそうとしていたのか分からなくなります。
        .presentationDetents([.height(320)])
    }
}
