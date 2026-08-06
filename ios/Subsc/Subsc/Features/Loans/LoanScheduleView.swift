import SwiftData
import SwiftUI

/// 返済予定表です。各回の日付・返済額・元金・利息・残高を並べます。
///
/// **予定表は常に計算結果です。** ここでは編集させません。滞納や繰上返済は返済履歴から記録し、
/// その結果としてこの表が組み直されます。
struct LoanScheduleView: View {
    let loan: Loan

    private var payments: [LoanPayment] {
        LoanPaymentStore.sortedPayments(on: loan)
    }

    /// 年ごとにまとめます。数十〜数百回になるため、区切りが無いと現在地を見失います。
    private var groupedByYear: [(year: Int, payments: [LoanPayment])] {
        Dictionary(grouping: payments, by: \.year)
            .sorted { $0.key < $1.key }
            .map { (year: $0.key, payments: $0.value.sorted { $0.period < $1.period }) }
    }

    var body: some View {
        List {
            if payments.isEmpty {
                Section {
                    ContentUnavailableView(
                        "返済予定がありません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("借入の条件を入力すると、返済予定表が作られます。")
                    )
                }
                .glassListRow()
            } else {
                summarySection
                ForEach(groupedByYear, id: \.year) { group in
                    Section("\(String(group.year))年") {
                        ForEach(group.payments) { payment in
                            LoanScheduleRow(payment: payment)
                        }
                    }
                    .glassListRow()
                }
            }
        }
        .liquidGlassScreen()
        .navigationTitle("返済予定表")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        Section {
            LabeledContent("返済回数", value: "\(payments.filter { $0.status != .missed }.count)回")
            LabeledContent("利息の合計") {
                Text(
                    payments.reduce(0) { $0 + $1.interestPortion },
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .monospacedDigit()
            }
            LabeledContent("返済総額") {
                Text(
                    payments.reduce(0) { $0 + $1.effectiveAmount },
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .monospacedDigit()
            }
        }
        .glassListRow()
    }
}

/// 予定表の1行です。**内訳（元金・利息）を必ず見せます。** 返済額だけでは何に効いたか分かりません。
struct LoanScheduleRow: View {
    let payment: LoanPayment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let dueOn = payment.dueOn {
                    Text(dueOn, format: .dateTime.month().day())
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("\(payment.month)月")
                        .font(.subheadline.weight(.semibold))
                }
                if payment.status != .scheduled {
                    Text(payment.status.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(BlackCatPalette.surfaceElevated, in: Capsule())
                }
                Spacer()
                Text(
                    payment.effectiveAmount,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            }

            HStack(spacing: 10) {
                Text("元金 \(payment.principalPortion.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
                Text("利息 \(payment.interestPortion.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
                Spacer()
                Text("残高 \(payment.balanceAfter.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
