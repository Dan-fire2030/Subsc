import SwiftUI

/// 選んだ日の明細です。カレンダーの下に置きます。
///
/// **行の作りはホームの一覧に揃えます**（左端の色の印・名前・補足・金額）。
/// 同じものを別の見た目で出すと、同じアプリの中で二度覚えることになります。
struct CalendarDayList: View {
    let day: CalendarDay?
    /// 未入力の変動費が選ばれたときに、実績入力へ渡します。
    let onSelectUnentered: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SubscSpacing.s) {
            if let day {
                // **見出しに肉球を添えます（2026-10-15）。** 猫は飾りとしてさりげなく出す方針です。
                Label {
                    Text(headline(for: day))
                } icon: {
                    PawPrint()
                        .fill(SubscPalette.catBody)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                .font(SubscTypography.label)
                .foregroundStyle(SubscPalette.textMuted)
                .padding(.horizontal, SubscSpacing.xs)

                if day.items.isEmpty {
                    Text("この日に出ていくお金はありません。")
                        .font(.body)
                        .foregroundStyle(SubscPalette.textMuted)
                        .padding(.vertical, SubscSpacing.m)
                        .padding(.horizontal, SubscSpacing.xs)
                } else {
                    ForEach(day.items) { item in
                        row(for: item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 見出しです。**日付・件数・合計**を1行に置きます。
    private func headline(for day: CalendarDay) -> String {
        let dateText = day.date.formatted(.dateTime.month().day().weekday(.abbreviated))
        guard !day.items.isEmpty else { return dateText }
        let amount = day.total.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        return "\(dateText)・\(day.items.count)件・\(amount)"
    }

    @ViewBuilder
    private func row(for item: CalendarDayItem) -> some View {
        let content = HStack(spacing: SubscSpacing.m) {
            PastelRowIcon(systemImage: item.costType.systemImage, colorHex: item.colorHex)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(SubscTypography.body)
                        .foregroundStyle(SubscPalette.text)
                    if item.isPaused {
                        badge("停止中")
                    }
                    if item.isUnentered {
                        badge("未入力")
                    }
                }
                Text(item.subtitle)
                    .font(SubscTypography.label)
                    .foregroundStyle(SubscPalette.textMuted)
            }

            Spacer(minLength: SubscSpacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(SubscTypography.rowAmount)
                    .monospacedDigit()
                    .foregroundStyle(SubscPalette.text)
                if item.isEstimated {
                    // **断定しません。** 実績ではなく直近からの推定です。
                    Text("見込み")
                        .font(SubscTypography.badge)
                        .foregroundStyle(SubscPalette.textMuted)
                }
            }
        }
        // **ホームの一覧と同じ、費目の色のカードにします（2026-10-15）。**
        .padding(.vertical, SubscSpacing.m)
        .padding(.leading, SubscSpacing.m)
        .padding(.trailing, SubscSpacing.l)
        .background(
            PastelTint.card(for: item.colorHex),
            in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.row, style: .continuous)
        )
        .contentShape(Rectangle())

        // **未入力の行だけ押せます。** 押して何も起きない行を混ぜると、
        // どこが押せるのか分からなくなります。
        if item.isUnentered, let clientID = item.subscriptionClientID {
            Button { onSelectUnentered(clientID) } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint("金額を入力します")
        } else {
            content
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(SubscTypography.badge)
            .foregroundStyle(SubscPalette.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SubscPalette.surface.opacity(0.65), in: Capsule())
    }
}

/// 肉球です。真ん中の大きな玉と、上に並ぶ4つの小さな玉でできています。
private struct PawPrint: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGRect {
            CGRect(x: rect.minX + (x - r) * unit, y: rect.minY + (y - r) * unit, width: r * 2 * unit, height: r * 2 * unit)
        }
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + 7 * unit, y: rect.minY + 11.8 * unit, width: 10 * unit, height: 8.4 * unit))
        path.addEllipse(in: circle(5.5, 10.5, 2.2))
        path.addEllipse(in: circle(9.5, 6.5, 2.2))
        path.addEllipse(in: circle(14.5, 6.5, 2.2))
        path.addEllipse(in: circle(18.5, 10.5, 2.2))
        return path
    }
}
