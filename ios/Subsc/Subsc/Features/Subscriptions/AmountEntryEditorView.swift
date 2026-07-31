import SwiftData
import SwiftUI

/// 変動費の、ある月の金額を記録する画面です。新規の記録と既存の修正の両方に使います。
///
/// 年月を選べるようにしているのは、請求が翌月に届く費目で「先月ぶん」を後から
/// 入れられるようにするためです。
struct AmountEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let subscription: Subscription

    @State private var year: Int
    @State private var month: Int
    @State private var amount: Double
    @State private var errorMessage: String?

    private let selectableYears: [Int]

    init(subscription: Subscription, periodKey: Int, calendar: Calendar = .current) {
        self.subscription = subscription
        let initialYear = periodKey / 100
        let initialMonth = periodKey % 100
        _year = State(initialValue: initialYear)
        _month = State(initialValue: initialMonth)
        _amount = State(
            initialValue: AmountEntryStore.entry(on: subscription, periodKey: periodKey)?.amount ?? 0
        )

        // 選べる年は、今年の前後と、すでに記録がある年を必ず含めます。
        let thisYear = calendar.component(.year, from: .now)
        let recordedYears = (subscription.amountEntries ?? []).map(\.year)
        let lowerBound = min(thisYear - 5, recordedYears.min() ?? thisYear)
        let upperBound = max(thisYear + 1, recordedYears.max() ?? thisYear, initialYear)
        selectableYears = Array(lowerBound...upperBound).reversed()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("対象の月") {
                    Picker("年", selection: $year) {
                        ForEach(selectableYears, id: \.self) { year in
                            Text(verbatim: "\(year)年").tag(year)
                        }
                    }
                    Picker("月", selection: $month) {
                        ForEach(1...12, id: \.self) { month in
                            Text(verbatim: "\(month)月").tag(month)
                        }
                    }
                }
                .glassListRow()

                Section {
                    LabeledContent("金額") {
                        HStack(spacing: 6) {
                            Text(subscription.currency.symbol)
                                .foregroundStyle(.secondary)
                            TextField(
                                subscription.currency == .usd ? "19.99" : "8,200",
                                value: $amount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("amount-entry-field")
                        }
                    }
                } footer: {
                    if AmountEntryStore.hasRecord(on: subscription, periodKey: periodKey) {
                        Text("この月にはすでに記録があります。保存すると上書きされます。")
                    }
                }
                .glassListRow()

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .glassListRow()
                }
            }
            .liquidGlassScreen()
            .navigationTitle("金額を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("amount-entry-save-button")
                }
            }
        }
    }

    private var periodKey: Int { year * 100 + month }

    private func save() {
        guard amount >= 0 else {
            errorMessage = "金額は0以上で入力してください。"
            return
        }

        AmountEntryStore.record(
            amount: amount,
            year: year,
            month: month,
            on: subscription
        )

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "記録を保存できませんでした。もう一度お試しください。"
            return
        }

        Task {
            await NotificationService.reschedule(for: subscription)
        }
        dismiss()
    }
}
