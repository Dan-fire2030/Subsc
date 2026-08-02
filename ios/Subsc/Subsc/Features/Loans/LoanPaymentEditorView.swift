import SwiftData
import SwiftUI

/// 1回分の返済を記録・修正する画面です。
///
/// **繰上返済はここで扱います。** 予定額より多く入れると、上乗せぶんが全額元金へ充当され、
/// 完済が早まります（期間短縮型）。専用の画面を分けると、返済を記録するだけのつもりが
/// どちらの画面か迷うためです。
struct LoanPaymentEditorView: View {
    /// 記録の種類です。滞納か返済かの二択で、金額はそのあとに続きます。
    private enum Outcome: String, CaseIterable, Identifiable {
        case paid
        case missed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .paid: "返済した"
            case .missed: "滞納した"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let loan: Loan
    let payment: LoanPayment

    @State private var outcome: Outcome
    @State private var amount: Double
    @State private var operationError: String?

    /// すでに記録が付いている回か。取り消しボタンを出すかどうかの判断に使います。
    private var isRecorded: Bool {
        payment.status != .scheduled
    }

    private var isPrepayment: Bool {
        outcome == .paid && amount > payment.scheduledAmount
    }

    init(loan: Loan, payment: LoanPayment) {
        self.loan = loan
        self.payment = payment
        _outcome = State(initialValue: payment.status == .missed ? .missed : .paid)
        _amount = State(initialValue: payment.actualAmount ?? payment.scheduledAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let dueOn = payment.dueOn {
                        LabeledContent("返済日") {
                            Text(dueOn, format: .dateTime.year().month().day())
                        }
                    }
                    LabeledContent("予定額") {
                        Text(
                            payment.scheduledAmount,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                    }
                }
                .glassListRow()

                Section {
                    Picker("記録", selection: $outcome) {
                        ForEach(Outcome.allCases) { outcome in
                            Text(outcome.title).tag(outcome)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(3)
                    .glassSurface(cornerRadius: 14)

                    if outcome == .paid {
                        LabeledContent("実際に払った額") {
                            HStack(spacing: 6) {
                                Text("¥")
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "",
                                    value: $amount,
                                    format: .number.precision(.fractionLength(0))
                                )
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("loan-payment-amount-field")
                            }
                        }
                    }
                } footer: {
                    Text(footerText)
                }
                .glassListRow()

                if isRecorded {
                    Section {
                        Button("記録を取り消す", role: .destructive) {
                            clearRecord()
                        }
                    } footer: {
                        Text("予定の状態へ戻します。滞納で後ろへずれた予定も元に戻ります。")
                    }
                    .glassListRow()
                }
            }
            .liquidGlassScreen()
            .navigationTitle("返済の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { record() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("loan-payment-save-button")
                }
            }
            .alert(
                "記録できませんでした",
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
    }

    private var footerText: String {
        switch outcome {
        case .missed:
            return "その月の返済額は0になり、以降の予定が後ろへずれます。利息は残高へ繰り入れられます。"
        case .paid:
            return isPrepayment
                ? "予定額を超えたぶんは全額が元金へ充当され、完済が早まります。"
                : "予定どおり返済したものとして記録します。"
        }
    }

    private func record() {
        guard amount >= 0 else {
            operationError = "返済額は0以上で入力してください。"
            return
        }
        apply {
            switch outcome {
            case .paid:
                try LoanPaymentStore.recordPayment(
                    amount: amount,
                    period: payment.period,
                    on: loan
                )
            case .missed:
                try LoanPaymentStore.markMissed(period: payment.period, on: loan)
            }
        }
    }

    private func clearRecord() {
        apply {
            try LoanPaymentStore.clearRecord(period: payment.period, on: loan)
        }
    }

    /// 予定表の組み直しと保存をまとめます。
    /// **失敗したら書き戻しません。** 中途半端な予定表が残ると、残高の表示が実態とずれます。
    private func apply(_ operation: () throws -> LoanPaymentStore.SynchronizationResult) {
        do {
            let result = try operation()
            for removed in result.removed {
                modelContext.delete(removed)
            }
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            operationError = (error as? LocalizedError)?.errorDescription
                ?? "記録を保存できませんでした。もう一度お試しください。"
        }
    }
}
