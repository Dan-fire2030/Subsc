import SwiftUI

/// 繰上返済の試算です。「今◯円入れると何ヶ月早まり、利息がいくら減るか」を出します。
///
/// **記録は残りません。** ここは「もしこうしたら」を見るだけの画面で、実際に繰上返済したときは
/// 返済履歴から記録します。分けているのは、試したことが実績として残ると残高が狂うためです。
struct LoanPrepaymentSimulationView: View {
    let loan: Loan
    @State private var amount: Double = 100_000

    private var summary: LoanSummary {
        LoanSummary.make(for: loan)
    }

    private var terms: LoanTerms? {
        LoanSimulator.remainingTerms(for: loan, summary: summary)
    }

    /// 試算に失敗しても画面は壊しません。入力の途中で成立しない状態は普通に起こります。
    private var outcome: LoanSimulationOutcome? {
        guard let terms else { return nil }
        return try? LoanSimulator.prepayment(of: amount, on: terms)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("今の残高") {
                    Text(
                        summary.currentBalance,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .monospacedDigit()
                }
                LabeledContent("残り回数", value: "\(summary.remainingCount)回")
            }
            .glassListRow()

            Section {
                LabeledContent("上乗せする額") {
                    HStack(spacing: 6) {
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField(
                            "100,000",
                            value: $amount,
                            format: .number.precision(.fractionLength(0))
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("prepayment-amount-field")
                    }
                }

                quickAmounts
            } header: {
                Text("繰上返済")
            } footer: {
                Text("次の返済に上乗せした場合の試算です。上乗せぶんは全額が元金へ充当されます（期間短縮型）。")
            }
            .glassListRow()

            if let outcome {
                // 繰上返済では毎月の返済額は変わりません。並べても意味が無いので出しません。
                LoanSimulationResultSection(outcome: outcome, showsMonthlyPayment: false)
            } else {
                LoanSimulationUnavailableSection(
                    message: terms == nil
                        ? "残っている返済がないため試算できません。"
                        : "この金額では試算できません。金額を確認してください。"
                )
            }
        }
        .liquidGlassScreen()
        .navigationTitle("繰上返済の試算")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// よく使う額です。数字を打たずに効果の当たりを付けられるようにしています。
    private var quickAmounts: some View {
        HStack(spacing: 8) {
            ForEach([100_000.0, 300_000.0, 500_000.0, 1_000_000.0], id: \.self) { candidate in
                Button {
                    amount = candidate
                } label: {
                    Text(candidate.formatted(.number.notation(.compactName)))
                        .font(.caption.weight(amount == candidate ? .bold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            amount == candidate ? Color.accentColor.opacity(0.22) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(candidate.formatted(.currency(code: "JPY").precision(.fractionLength(0))))を上乗せ"
                )
            }
        }
        .padding(.vertical, 2)
    }
}
