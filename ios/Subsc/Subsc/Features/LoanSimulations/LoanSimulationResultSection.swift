import SwiftUI

/// 試算の結果を「変える前 → 変えたあと」で見せるセクションです。
///
/// 繰上返済と利率変更で見せたいものが同じなので、共通の部品にしています。
/// **効果は必ず差分で示します。** 変えたあとの数字だけでは、得か損かが読み取れません。
struct LoanSimulationResultSection: View {
    let outcome: LoanSimulationOutcome
    /// 毎月の返済額の比較を出すか。繰上返済では返済額が変わらないため出しません。
    var showsMonthlyPayment = true

    private var savesInterest: Bool { outcome.interestSaved > 0 }

    var body: some View {
        Section("試算の結果") {
            LabeledContent(savesInterest ? "減る利息" : "増える利息") {
                Text(
                    abs(outcome.interestSaved),
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(savesInterest ? Color.green : Color.orange)
                .monospacedDigit()
                .contentTransition(.numericText())
            }

            LabeledContent(outcome.monthsShortened >= 0 ? "早まる回数" : "延びる回数") {
                Text("\(abs(outcome.monthsShortened))回")
                    .monospacedDigit()
            }

            if showsMonthlyPayment {
                LabeledContent("毎月の返済額") {
                    HStack(spacing: 6) {
                        Text(
                            outcome.baselineMonthlyPayment,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .foregroundStyle(BlackCatPalette.textMuted)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(
                            outcome.simulatedMonthlyPayment,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .fontWeight(.semibold)
                    }
                    .monospacedDigit()
                }
            }

            if let baselineDate = outcome.baselineCompletionDate,
               let simulatedDate = outcome.simulatedCompletionDate {
                LabeledContent("完済予定") {
                    HStack(spacing: 6) {
                        Text(baselineDate, format: .dateTime.year().month())
                            .foregroundStyle(BlackCatPalette.textMuted)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(simulatedDate, format: .dateTime.year().month())
                            .fontWeight(.semibold)
                    }
                }
            }

            LabeledContent("利息の合計") {
                HStack(spacing: 6) {
                    Text(
                        outcome.baseline.totalInterest,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .foregroundStyle(BlackCatPalette.textMuted)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(
                        outcome.simulated.totalInterest,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .fontWeight(.semibold)
                }
                .monospacedDigit()
            }
        }
        .glassListRow()
    }
}

/// 試算できないときの案内です。残高が無い・条件が足りない、のどちらも同じ形で伝えます。
struct LoanSimulationUnavailableSection: View {
    let message: String

    var body: some View {
        Section {
            Text(message)
                .font(.footnote)
                .foregroundStyle(BlackCatPalette.textMuted)
        }
        .glassListRow()
    }
}
