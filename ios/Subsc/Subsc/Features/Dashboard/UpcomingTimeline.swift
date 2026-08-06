import SwiftUI

/// これから出ていくお金を、**時間軸**として並べます。
///
/// **金額の羅列では出せない情報があります。** 点の縦の間隔が日付の近さを表すので、
/// 「しばらく無い」「立て続けに来る」が一目で分かります。
///
/// **今日だけ金色にします。** 金は画面で一点にしか使わないと決めているため、
/// 「金＝いま効くもの」という読み方が育ちます。
struct UpcomingTimeline: View {
    let items: [DashboardListItem]

    /// 何件まで出すかです。**多すぎると一覧と役割が重なります。**
    /// 全件は下の費目一覧で見られるので、ここは近い順に数件だけ示します。
    static let maximumCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.prefix(Self.maximumCount).enumerated()), id: \.element.id) { index, item in
                UpcomingTimelineRow(item: item, isFirst: index == 0)
            }
        }
        .background(alignment: .leading) {
            // 縦線は行の背後に1本だけ通します。行ごとに引くと、
            // 行間で途切れて「点線」に見えてしまいます。
            Capsule()
                .fill(BlackCatPalette.chartTrack)
                .frame(width: 2)
                .padding(.vertical, 14)
                .padding(.leading, 4)
        }
    }
}

/// 時間軸の1行です。
struct UpcomingTimelineRow: View {
    let item: DashboardListItem
    /// 直近の1件かどうかです。金色の点はここだけに出します。
    let isFirst: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var dotSize: CGFloat { isFirst ? 10 : 8 }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isFirst ? BlackCatPalette.accent : BlackCatPalette.chartTrack)
                .frame(width: dotSize, height: dotSize)
                .frame(width: 10)
                .accessibilityHidden(true)

            Text(relativeLabel)
                .font(.caption)
                .foregroundStyle(isFirst ? BlackCatPalette.accent : BlackCatPalette.textMuted)
                .fontWeight(isFirst ? .bold : .regular)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 62, alignment: .leading)

            Text(item.name)
                .font(BlackCatType.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let amount = item.nextDueAmount {
                Text(amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(BlackCatType.rowAmount)
                    .monospacedDigit()
            }
        }
        // 見た目が細くても、触れる高さは指のサイズを守ります。
        .frame(minHeight: 44)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 「今日」「あと3日」のように、**日付そのものより残りの日数**を先に出します。
    /// 行動に効くのは何月何日かではなく、あと何日かだからです。
    private var relativeLabel: String {
        guard let dueDate = item.nextDueDate else { return "" }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0
        if days == 0 { return "今日" }
        if days < 0 { return "期日超過" }
        return "あと\(days)日"
    }
}
