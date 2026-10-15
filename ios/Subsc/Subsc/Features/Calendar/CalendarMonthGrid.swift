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
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
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
                        .font(SubscTypography.badge)
                        .foregroundStyle(weekdayColor(at: index))
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days) { day in
                    CalendarDayCell(
                        day: day,
                        dayNumber: calendar.component(.day, from: day.date),
                        isSelected: day.date == selectedDate,
                        showsAmounts: showsAmounts
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(day.date) }
                }
            }
        }
        // **月のマスを白いカードに載せます（2026-10-15）。** 支払い日を費目の色で塗るので、
        // 地の上に直接並べると、塗ったマスと地の境目がぼやけます。
        .padding(SubscSpacing.s)
        .background(SubscPalette.surface, in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.card, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// 日曜と土曜だけ色を分けます。**祝日は扱いません**（日本の祝日表を持たないため、
    /// 半端に色を付けると「抜けている」と読まれます）。
    private func weekdayColor(at index: Int) -> Color {
        let weekday = (calendar.firstWeekday - 1 + index) % 7
        switch weekday {
        case 0: return SubscPalette.sunday
        case 6: return SubscPalette.saturday
        default: return SubscPalette.textMuted
        }
    }
}

/// マス1つです。
private struct CalendarDayCell: View {
    let day: CalendarDay
    /// マスに出す日付の数字です。**「15日」ではなく「15」だけを出します（2026-10-15）。**
    /// 今日を丸で囲むようになり、「日」まで入れると丸からはみ出しました。曜日の見出しがあるので数字だけで足ります。
    let dayNumber: Int
    let isSelected: Bool
    let showsAmounts: Bool

    /// **金額を出しても高さを変えません。** 切り替えるたびに月の形が動くと、
    /// 同じ月を見ている感覚が切れます。出さないときはこのぶんの余白が空きます。
    private let height: CGFloat = 58

    var body: some View {
        VStack(spacing: 3) {
            // **今日は濃い丸で囲みます（2026-10-15）。** 支払い日を色で塗るようになったので、
            // 今日まで色の枠で示すと、どちらの印か見分けられません。形で分けます。
            Text("\(dayNumber)")
                .font(SubscTypography.label)
                .fontWeight(day.isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(day.isToday ? SubscPalette.background : SubscPalette.text)
                .frame(minWidth: 24, minHeight: 24)
                .background {
                    if day.isToday {
                        Circle().fill(SubscPalette.text)
                    }
                }

            dots

            if showsAmounts {
                amountAndCount
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        // **支払いのある日は、その費目の色で薄く塗ります（2026-10-15）。** 複数あるときは
        // 先頭（借入→金額の大きい順）の色です。ほかの費目は点で残ります。
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        }
        // **選んだ日はアクセントの枠で示します。** 面の色は費目の色に使っているためです。
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? SubscPalette.accent : .clear, lineWidth: 2)
        }
        // **過ぎた日は淡く落とします。** 「もう出ていった」と「これから出ていく」を分けます。
        .opacity(day.isInDisplayedMonth ? (day.isPast ? 0.48 : 1) : 0.22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var fill: Color {
        guard day.isInDisplayedMonth, let first = day.items.first else { return .clear }
        return PastelTint.card(for: first.colorHex)
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(day.visibleItems) { item in
                Circle()
                    .strokeBorder(
                        // 未入力は塗らずに輪で描き、色の意味は保ちます。
                        item.isUnentered ? SubscPalette.harmonized(from: item.colorHex) : .clear,
                        lineWidth: 1.5
                    )
                    .background {
                        Circle().fill(
                            item.isUnentered
                                ? .clear
                                : SubscPalette.harmonized(from: item.colorHex)
                        )
                    }
                    .frame(width: 5, height: 5)
            }
            if day.hiddenItemCount > 0 {
                Text("+\(day.hiddenItemCount)")
                    .font(.system(size: 8))
                    .foregroundStyle(SubscPalette.textMuted)
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
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(SubscPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if day.items.contains(where: \.isUnentered) {
                Text("未入力")
                    .font(.system(size: 9))
                    .foregroundStyle(SubscPalette.textMuted)
            }

            if day.showsCountBadge {
                Text("\(day.items.count)件")
                    .font(.system(size: 8))
                    .monospacedDigit()
                    .foregroundStyle(SubscPalette.textMuted)
                    .padding(.horizontal, 4)
                    .background(SubscPalette.surface.opacity(0.65), in: Capsule())
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
