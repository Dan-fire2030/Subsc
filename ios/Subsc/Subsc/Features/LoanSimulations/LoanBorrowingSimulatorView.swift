import SwiftUI

/// 借入シミュレーターです。**まだ借りていなくても試せます。**
///
/// 借入額・年利・返済回数から、毎月の返済額と総額を出します。登録を求めないのは、
/// 「借りるかどうか」を決める段階でこそ必要な機能だからです。
struct LoanBorrowingSimulatorView: View {
    @State private var principal: Double = 1_000_000
    @State private var annualRatePercent: Double = 3.0
    @State private var installmentCount: Int = 60
    @State private var method: RepaymentMethod = .equalPayment

    /// 試算に使う条件です。開始日は今日にします。**保存しないので日付の意味は薄い**のですが、
    /// ボーナス月の判定と完済予定の表示に暦が要ります。
    private var terms: LoanTerms {
        LoanTerms(
            principal: principal,
            annualRatePercent: annualRatePercent,
            installmentCount: installmentCount,
            method: method,
            firstDueDate: .now
        )
    }

    private var schedule: LoanSchedule? {
        try? LoanSimulator.estimate(terms)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("借入額") {
                    HStack(spacing: 6) {
                        Text("¥")
                            .foregroundStyle(BlackCatPalette.textMuted)
                        TextField(
                            "1,000,000",
                            value: $principal,
                            format: .number.precision(.fractionLength(0))
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("simulator-principal-field")
                    }
                }

                LabeledContent("年利") {
                    HStack(spacing: 6) {
                        TextField(
                            "3.0",
                            value: $annualRatePercent,
                            format: .number.precision(.fractionLength(0...3))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("simulator-rate-field")
                        Text("％")
                            .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }

                LabeledContent("返済回数") {
                    HStack(spacing: 6) {
                        TextField("60", value: $installmentCount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("simulator-count-field")
                        Text("回")
                            .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }

                Picker("返済方式", selection: $method) {
                    // リボ払いは残高の帯が要るため、この画面では扱いません。
                    ForEach([RepaymentMethod.equalPayment, .interestFree]) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .padding(3)
                .glassSurface(cornerRadius: 14)
            } header: {
                Text("借入の条件")
            } footer: {
                Text("登録しなくても試せます。ここでの入力は保存されません。")
            }
            .glassListRow()

            if let schedule, let first = schedule.installments.first {
                Section("試算の結果") {
                    LabeledContent("毎月の返済額") {
                        Text(first.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    LabeledContent("返済総額") {
                        Text(
                            schedule.totalPayment,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("利息の合計") {
                        Text(
                            schedule.totalInterest,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("返済回数", value: "\(schedule.paymentCount)回")
                }
                .glassListRow()
            } else {
                LoanSimulationUnavailableSection(
                    message: "この条件では試算できません。借入額と返済回数を1以上で入力してください。"
                )
            }
        }
        .liquidGlassScreen()
        .navigationTitle("借入シミュレーター")
        .navigationBarTitleDisplayMode(.inline)
    }
}
