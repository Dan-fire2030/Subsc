import SwiftData
import SwiftUI

/// 返済履歴です。返済済み・滞納の記録を見直し、あとから直せます。
///
/// **通知のボタンは押し間違えます。** 直せる場所が無いと、誤った「滞納」で完済予定日が
/// ずれたまま戻せません。ここが唯一の入力窓口です。
struct LoanHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let loan: Loan
    @State private var editingPayment: LoanPayment?
    @State private var operationError: String?

    private var payments: [LoanPayment] {
        LoanPaymentStore.sortedPayments(on: loan)
    }

    /// 記録済みの回です。新しい順に並べます。直したいのは大抵いちばん最近の回だからです。
    private var recorded: [LoanPayment] {
        payments.filter { $0.status != .scheduled }.reversed()
    }

    /// これから返す回です。**先に返した場合もここから記録できます。**
    private var upcoming: [LoanPayment] {
        payments.filter { $0.status == .scheduled }
    }

    var body: some View {
        List {
            if payments.isEmpty {
                Section {
                    ContentUnavailableView(
                        "返済の記録がありません",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("借入の条件を入力すると、返済予定が作られます。")
                    )
                }
                .glassListRow()
            } else {
                if !recorded.isEmpty {
                    Section("記録済み") {
                        ForEach(recorded) { payment in
                            paymentRow(payment)
                        }
                    }
                    .glassListRow()
                }

                if !upcoming.isEmpty {
                    Section("これからの返済") {
                        ForEach(upcoming.prefix(12)) { payment in
                            paymentRow(payment)
                        }
                    }
                    .glassListRow()
                }
            }
        }
        .liquidGlassScreen()
        .navigationTitle("返済履歴")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPayment) { payment in
            LoanPaymentEditorView(loan: loan, payment: payment)
        }
        .alert(
            "操作を完了できませんでした",
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(operationError ?? "")
        }
    }

    private func paymentRow(_ payment: LoanPayment) -> some View {
        Button {
            editingPayment = payment
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if let dueOn = payment.dueOn {
                        Text(dueOn, format: .dateTime.year().month().day())
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("\(payment.year)年\(payment.month)月")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(payment.status.title)
                        .font(.caption)
                        .foregroundStyle(payment.status == .missed ? .orange : .secondary)
                }
                Spacer()
                Text(
                    payment.effectiveAmount,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.subheadline)
                .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
