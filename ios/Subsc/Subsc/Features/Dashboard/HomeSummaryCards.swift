import SwiftUI

/// ホームの先頭に並べる2枚のカードです。**今月の合計**と**次の支払い**を同じ重みで並べます。
///
/// **2026-10-15にレポートをホームから別画面へ移しました。** ホームでは「いくら使っているか」と
/// 「次に何が出ていくか」だけを一目で見せ、グラフや期間の切り替えは合計カードの先（レポート）へ預けます。
/// 合計カードの上には、相棒の猫が手をかけてのぞきます。
struct HomeSummaryCards: View {
    /// 今月の集計です。**種別の絞り込みは呼び出し側で適用済み**です。
    let report: PaymentReport
    /// 次に期日が来るものです。無ければ「予定なし」を出します。
    let nextItem: DashboardListItem?
    let catMood: CatMood
    /// 合計カードを押したときに呼びます。画面の移動は呼び出し側（`navigationDestination`）が持ちます。
    ///
    /// **カードに `NavigationLink` を直接置きません（2026-10-15）。** 一覧の行の中に置くと、
    /// 一覧が行の右端に「›」を足し、2枚のカードのあいだに矢印が浮いて見えました。
    let openReport: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: SubscSpacing.m))
            : AnyLayout(HStackLayout(alignment: .top, spacing: SubscSpacing.m))

        layout {
            totalCard
            nextPaymentCard
        }
        .padding(.top, HomeSummaryLayout.topRoom)
    }

    // MARK: - 今月の合計

    private var totalCard: some View {
        Button(action: openReport) {
            VStack(alignment: .leading, spacing: SubscSpacing.s) {
                HStack {
                    Text("今月の合計")
                        .font(.footnote)
                        .foregroundStyle(SubscPalette.textMuted)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SubscPalette.textMuted)
                        .accessibilityHidden(true)
                }

                Text(report.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(SubscPalette.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: report.total))

                BreakdownStrip(entries: largestEntries, total: report.total)

                Text(report.entries.isEmpty ? "今月の支払いはありません" : "\(report.entries.count)件")
                    .font(.caption)
                    .foregroundStyle(SubscPalette.textMuted)
            }
            .padding(SubscSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SubscPalette.surface, in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.card, style: .continuous))
            .shadow(color: SubscPalette.accent.opacity(0.08), radius: 10, y: 4)
            .overlay(alignment: .topTrailing) {
                // **猫は金額に重ねず、右上の角に手をかけさせます。** 数字を読む邪魔をしないためです。
                CatCompanionView(mood: catMood)
                    .frame(width: HomeSummaryLayout.catSize, height: HomeSummaryLayout.catSize)
                    .offset(x: -SubscSpacing.m, y: -HomeSummaryLayout.catLift)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今月の合計 \(report.total.formatted(.currency(code: "JPY").precision(.fractionLength(0))))、\(report.entries.count)件")
        .accessibilityHint("レポートを開きます")
        .accessibilityIdentifier("home-total-card")
    }

    /// 帯に出す費目です。**金額の大きい順**に先頭から取ります。
    private var largestEntries: [ReportEntry] {
        Array(report.entries.sorted { $0.amount > $1.amount }.prefix(HomeSummaryLayout.breakdownLimit))
    }

    // MARK: - 次の支払い

    @ViewBuilder
    private var nextPaymentCard: some View {
        let hex = nextItem.map(colorHex(for:)) ?? SubscPalette.harmonizedFallbackHex

        VStack(alignment: .leading, spacing: SubscSpacing.xs) {
            Text("次の支払い")
                .font(.footnote)
                .foregroundStyle(SubscPalette.textMuted)

            if let nextItem {
                Text(RelativeDueLabel.text(for: nextItem.nextDueDate))
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(SubscPalette.text)
                Text(nextItem.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SubscPalette.text)
                    .lineLimit(1)
                if let amount = nextItem.nextDueAmount {
                    Text(amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                        .font(SubscTypography.rowAmount)
                        .foregroundStyle(SubscPalette.text)
                        .monospacedDigit()
                }
            } else {
                Text("予定なし")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(SubscPalette.text)
            }
        }
        .padding(SubscSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelTint.card(for: hex), in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-next-payment-card")
    }

    private func colorHex(for item: DashboardListItem) -> String {
        switch item {
        case .subscription(let subscription): subscription.colorHex
        case .loan: CostType.loan.colorHex
        }
    }
}

/// `HomeSummaryCards` の寸法です。
private enum HomeSummaryLayout {
    /// のぞく猫の大きさです。**合計の数字より目立たない**大きさにします。
    static let catSize: CGFloat = 56
    /// 猫の前足（設計空間の y≒82）がカードの上端に重なるよう、上へずらす量です。
    static let catLift: CGFloat = 46
    /// 猫がはみ出すぶん、カードの上に空ける余白です。
    static let topRoom: CGFloat = 38
    /// 内訳の帯に出す費目の数です。多すぎると帯が細切れになり、色の比較ができません。
    static let breakdownLimit = 5
}

/// 今月の合計の内訳を、1本の帯で見せます。
///
/// 色は費目の色（パステルへ寄せた色）です。**金額が小さい費目も消えないよう**、
/// 下地（`chartTrack`）を敷いたうえで、各区間に最小幅を持たせます。
private struct BreakdownStrip: View {
    let entries: [ReportEntry]
    let total: Double

    private let minimumFraction = 0.04

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(entries) { entry in
                    Rectangle()
                        .fill(SubscPalette.harmonized(from: entry.colorHex))
                        .frame(width: width(for: entry, in: proxy.size.width))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 10)
        .background(SubscPalette.chartTrack)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func width(for entry: ReportEntry, in available: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let spacing = CGFloat(max(entries.count - 1, 0)) * 2
        let fraction = max(entry.amount / total, minimumFraction)
        return max(0, (available - spacing) * CGFloat(fraction))
    }
}
