import SwiftUI

/// 月のマスを並べます。
///
/// **文字サイズをここだけ制限しています。** 7列は横幅が決まっており、
/// 特大の文字では日付すら入りません。**内容の本体は下の一覧**にあり、
/// そちらは制限していないので、読む手段は失われません。
struct CalendarMonthGrid: View {
    let days: [CalendarDay]
    let selectedDate: Date?
    let showsAmounts: Bool
    let calendar: Calendar
    let onSelect: (Date) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    /// 曜日の見出しです。**端末の設定した週の始まりに合わせて回します。**
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(BlackCatType.badge)
                        .foregroundStyle(weekdayColor(at: index))
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(days) { day in
                    CalendarDayCell(
                        day: day,
                        isSelected: day.date == selectedDate,
                        showsAmounts: showsAmounts
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(day.date) }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// 日曜と土曜だけ色を分けます。**祝日は扱いません**（日本の祝日表を持たないため、
    /// 半端に色を付けると「抜けている」と読まれます）。
    private func weekdayColor(at index: Int) -> Color {
        let weekday = (calendar.firstWeekday - 1 + index) % 7
        switch weekday {
        case 0: return BlackCatPalette.Category.living
        case 6: return BlackCatPalette.Category.watch
        default: return BlackCatPalette.textMuted
        }
    }
}

/// マス1つです。
private struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let showsAmounts: Bool

    /// **金額を出しても高さを変えません。** 切り替えるたびに月の形が動くと、
    /// 同じ月を見ている感覚が切れます。出さないときはこのぶんの余白が空きます。
    private let height: CGFloat = 58

    var body: some View {
        VStack(spacing: 3) {
            Text(day.date.formatted(.dateTime.day()))
                .font(BlackCatType.label)
                .foregroundStyle(day.isToday ? BlackCatPalette.accent : BlackCatPalette.text)
                .fontWeight(day.isToday ? .bold : .regular)

            dots

            if showsAmounts {
                amountAndCount
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? BlackCatPalette.surface : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    day.isToday ? BlackCatPalette.accent.opacity(0.55) : .clear,
                    lineWidth: 1.5
                )
        }
        // **過ぎた日は淡く落とします。** 「もう出ていった」と「これから出ていく」を分けます。
        .opacity(day.isInDisplayedMonth ? (day.isPast ? 0.48 : 1) : 0.22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(day.visibleItems) { item in
                Circle()
                    .strokeBorder(
                        // 未入力は塗らずに輪で描き、色の意味は保ちます。
                        item.isUnentered ? BlackCatPalette.harmonized(from: item.colorHex) : .clear,
                        lineWidth: 1.5
                    )
                    .background {
                        Circle().fill(
                            item.isUnentered
                                ? .clear
                                : BlackCatPalette.harmonized(from: item.colorHex)
                        )
                    }
                    .frame(width: 5, height: 5)
            }
            if day.hiddenItemCount > 0 {
                Text("+\(day.hiddenItemCount)")
                    .font(.system(size: 8))
                    .foregroundStyle(BlackCatPalette.textMuted)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var amountAndCount: some View {
        VStack(spacing: 1) {
            if day.total > 0 {
                Text(day.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if day.items.contains(where: \.isUnentered) {
                Text("未入力")
                    .font(.system(size: 9))
                    .foregroundStyle(BlackCatPalette.textMuted)
            }

            if day.showsCountBadge {
                Text("\(day.items.count)件")
                    .font(.system(size: 8))
                    .monospacedDigit()
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .padding(.horizontal, 4)
                    .background(BlackCatPalette.surfaceElevated, in: Capsule())
            }
        }
    }

    /// 読み上げは日付と中身をひと続きにします。点は形なので読み上げても伝わりません。
    private var accessibilityLabel: String {
        let dateText = day.date.formatted(.dateTime.month().day())
        guard !day.items.isEmpty else { return "\(dateText) 予定なし" }
        let amount = day.total.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        return "\(dateText) \(day.items.count)件 合計\(amount)"
    }
}
