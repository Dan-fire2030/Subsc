import SwiftData
import SwiftUI

/// 費目別料金の詳細を全件表示するシートです。
/// カード上のグラフは上位数件しか出さないため、残りをここで確認できるようにしています。
///
/// **行を押すとその費目・借入の編集を開きます（2026-08-20）。**
/// グラフから内訳へ降りてきた利用者は、そこで気になったものを直したいはずで、
/// 一覧まで戻って同じものを探し直すのは遠回りです。
struct ReportBreakdownSheet: View {
    let entries: [ReportEntry]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subscription.renewalDate) private var subscriptions: [Subscription]
    @Query(sort: \Loan.createdAt) private var loans: [Loan]
    @State private var editingSubscription: Subscription?
    @State private var editingLoan: Loan?

    private var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            // **地は他の画面と同じ平らな色にします（2026-10-15）。**
            // 以前は斜めのグラデーションにすりガラスを重ねていましたが、パステルの画面では
            // ここだけ別の世界観に見えます。行を費目の色のカードにして、色はそちらで出します。
            ZStack {
                SubscPalette.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("合計")
                                .font(.caption)
                                .foregroundStyle(SubscPalette.textMuted)
                            Text(
                                total,
                                format: .currency(code: "JPY").precision(.fractionLength(0))
                            )
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(SubscPalette.text)
                            .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            SubscPalette.surface,
                            in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.card, style: .continuous)
                        )

                        ForEach(entries) { entry in
                            // アーカイブや削除で対象が消えている行は押せません。
                            // 開く先が無いのに反応すると、押しても何も起きない行になります。
                            if let target = ReportEntryTarget.resolve(
                                entry: entry,
                                subscriptions: subscriptions,
                                loans: loans
                            ) {
                                Button {
                                    open(target)
                                } label: {
                                    BreakdownRow(
                                        entry: entry,
                                        total: total,
                                        isEditable: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("編集を開きます")
                            } else {
                                BreakdownRow(
                                    entry: entry,
                                    total: total,
                                    isEditable: false
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("費目別料金")
            .navigationBarTitleDisplayMode(.inline)
            .adaptiveNavigationBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(SubscPalette.text)
                }
            }
            .sheet(item: $editingSubscription) { subscription in
                SubscriptionFormView(subscription: subscription)
            }
            .sheet(item: $editingLoan) { loan in
                LoanFormView(loan: loan)
            }
        }
    }

    private func open(_ target: ReportEntryTarget) {
        switch target {
        case .subscription(let subscription): editingSubscription = subscription
        case .loan(let loan): editingLoan = loan
        }
    }
}

private struct BreakdownRow: View {
    let entry: ReportEntry
    let total: Double
    /// 押して編集を開けるかどうか。開けるときだけ、押せることが分かる印を出します。
    let isEditable: Bool

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return entry.amount / total
    }

    var body: some View {
        HStack(spacing: 12) {
            // **グラフ本体と同じ寄せ方を通します（2026-08-11）。** 色の出どころは
            // `ReportChartPalette.breakdownBaseHex` で、ホームの一覧と同じ丸のアイコンにします（2026-10-15）。
            PastelRowIcon(
                systemImage: entry.costType.systemImage,
                colorHex: ReportChartPalette.breakdownBaseHex(for: entry.colorHex)
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SubscPalette.text)
                        .lineLimit(1)

                    if entry.isEstimated {
                        // 実績が未入力で、直近の実績から見込んだ額であることを示します。
                        Text("見込み")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SubscPalette.surface.opacity(0.65), in: Capsule())
                            .foregroundStyle(SubscPalette.text)
                    }
                }

                Text(
                    ratio,
                    format: .percent.precision(.fractionLength(1))
                )
                .font(.caption)
                .foregroundStyle(SubscPalette.textMuted)
            }

            Spacer(minLength: 8)

            Text(
                entry.amount,
                format: .currency(code: "JPY").precision(.fractionLength(0))
            )
            .font(SubscTypography.rowAmount)
            .foregroundStyle(SubscPalette.text)
            .monospacedDigit()

            if isEditable {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SubscPalette.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .background(
            PastelTint.card(for: ReportChartPalette.breakdownBaseHex(for: entry.colorHex)),
            in: RoundedRectangle(cornerRadius: SubscSpacing.Corner.row, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
