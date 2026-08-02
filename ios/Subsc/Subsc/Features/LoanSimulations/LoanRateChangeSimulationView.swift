import SwiftUI

/// 利率が変わったときの影響を試算します。
///
/// 変動金利の見直し通知が来たときに、**返済額と総額がどれだけ動くか**を確かめるための画面です。
/// **先の利率は予測しません**（SPEC 4-5）。入れた利率がそのまま続く前提で計算します。
struct LoanRateChangeSimulationView: View {
    let loan: Loan
    @State private var annualRatePercent: Double

    init(loan: Loan) {
        self.loan = loan
        _annualRatePercent = State(initialValue: loan.annualRatePercent)
    }

    private var summary: LoanSummary {
        LoanSummary.make(for: loan)
    }

    private var terms: LoanTerms? {
        LoanSimulator.remainingTerms(for: loan, summary: summary)
    }

    private var outcome: LoanSimulationOutcome? {
        guard let terms, annualRatePercent >= 0 else { return nil }
        return try? LoanSimulator.rateChange(to: annualRatePercent, on: terms)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("今の年利") {
                    Text("\(loan.annualRatePercent.formatted(.number.precision(.fractionLength(0...3))))％")
                        .monospacedDigit()
                }
                LabeledContent("今の残高") {
                    Text(
                        summary.currentBalance,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .monospacedDigit()
                }
            }
            .glassListRow()

            Section {
                LabeledContent("変更後の年利") {
                    HStack(spacing: 6) {
                        TextField(
                            "1.5",
                            value: $annualRatePercent,
                            format: .number.precision(.fractionLength(0...3))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("rate-change-field")
                        Text("％")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(
                    "0.1％きざみで調整",
                    value: $annualRatePercent,
                    in: 0...30,
                    step: 0.1
                )
            } header: {
                Text("利率の変更")
            } footer: {
                Text("入れた利率が完済まで続く前提で計算します。先の利率は予測しません。")
            }
            .glassListRow()

            if let outcome {
                LoanSimulationResultSection(outcome: outcome)
            } else {
                LoanSimulationUnavailableSection(
                    message: terms == nil
                        ? "残っている返済がないため試算できません。"
                        : "この利率では試算できません。0以上の値を入力してください。"
                )
            }
        }
        .liquidGlassScreen()
        .navigationTitle("利率変更の影響")
        .navigationBarTitleDisplayMode(.inline)
    }
}
