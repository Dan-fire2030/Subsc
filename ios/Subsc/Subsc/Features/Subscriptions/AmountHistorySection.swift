import SwiftUI

/// 詳細画面に出す、変動費の月別の記録です。
///
/// 今月がまだ未入力のときは、いくらで見込んでいるかをその場で示します。
/// 見込みを実績と同じ見た目にすると「記録済みだ」と誤解されるためです。
struct AmountHistorySection: View {
    let subscription: Subscription
    let onEdit: (Int) -> Void

    private let displayLimit = 12

    var body: some View {
        Section {
            if !hasRecordForThisMonth {
                currentMonthRow
            }

            ForEach(subscription.sortedAmountEntries.prefix(displayLimit)) { entry in
                Button {
                    onEdit(entry.periodKey)
                } label: {
                    LabeledContent(periodLabel(entry.periodKey)) {
                        Text(
                            entry.yenAmount,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    }
                }
                .foregroundStyle(.primary)
            }

            Button {
                onEdit(currentPeriodKey)
            } label: {
                Label("金額を記録", systemImage: "plus.circle")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("record-amount-button")
        } header: {
            Text("月別の記録")
        } footer: {
            if subscription.sortedAmountEntries.isEmpty {
                Text("まだ記録がありません。記録するまでこの費目は0円として集計されます。")
            } else if subscription.sortedAmountEntries.count > displayLimit {
                Text("直近\(displayLimit)件を表示しています。")
            }
        }
        .glassListRow()
    }

    /// 今月ぶんの見込み額です。実績が無い月をどう扱っているかを利用者に見せます。
    @ViewBuilder
    private var currentMonthRow: some View {
        let resolved = subscription.monthlyAmount(forPeriodKey: currentPeriodKey)
        LabeledContent(periodLabel(currentPeriodKey)) {
            HStack(spacing: 6) {
                if resolved.source == .unavailable {
                    Text("未記録")
                        .foregroundStyle(BlackCatPalette.textMuted)
                } else {
                    Text("見込み")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(BlackCatPalette.accent)
                    Text(
                        resolved.amount,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .monospacedDigit()
                    .foregroundStyle(BlackCatPalette.textMuted)
                }
            }
        }
    }

    private var currentPeriodKey: Int {
        AmountEntry.periodKey(for: .now)
    }

    private var hasRecordForThisMonth: Bool {
        AmountEntryStore.hasRecord(on: subscription, periodKey: currentPeriodKey)
    }

    private func periodLabel(_ periodKey: Int) -> String {
        "\(periodKey / 100)年\(periodKey % 100)月"
    }
}
