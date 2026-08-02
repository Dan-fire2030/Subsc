import SwiftUI

/// `LoanFormView` のフォーム各セクションです。`body` から切り出しただけで、並び順は元のまま保っています。
extension LoanFormView {
    var basicSection: some View {
        Section("借入") {
            TextField("名前（例：住宅ローン、A社カードローン）", text: $input.name)
                .accessibilityIdentifier("loan-name-field")

            Picker("返済方式", selection: $input.method) {
                ForEach(RepaymentMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .accessibilityIdentifier("loan-method-picker")

            TextField("メモ（借入先など）", text: $input.note, axis: .vertical)
                .lineLimit(1...3)
        }
        .glassListRow()
    }

    /// 登録方式です。**契約書が手元に無くても始められるよう**、今の残高だけで登録する道を用意しています。
    var originSection: some View {
        Section {
            Picker("登録方法", selection: $input.origin) {
                ForEach(LoanOrigin.allCases) { origin in
                    Text(origin.title).tag(origin)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .glassSurface(cornerRadius: 14)
            .accessibilityIdentifier("loan-origin-picker")

            switch input.origin {
            case .fromOrigin:
                amountField("借入額", value: $input.originalPrincipal, placeholder: "1,000,000")
                DatePicker(
                    "借入日",
                    selection: $input.borrowedOn,
                    displayedComponents: .date
                )
                if input.method != .revolving {
                    countField("返済回数", value: $input.totalInstallments)
                }
            case .fromCurrentBalance:
                amountField("今の残高", value: $input.startingBalance, placeholder: "400,000")
                DatePicker(
                    "記録を始める月",
                    selection: $input.startedTrackingOn,
                    displayedComponents: .date
                )
                if input.method != .revolving {
                    countField("残りの返済回数", value: $input.startingInstallments)
                }
            }
        } header: {
            Text("金額と期間")
        } footer: {
            Text(
                input.origin == .fromOrigin
                    ? "借りたときの条件から、これまでの経過を含めて計算します。"
                    : "今の残高から、今日以降の予定だけを組み立てます。"
            )
        }
        .glassListRow()
    }

    var interestSection: some View {
        Section {
            Picker("金利", selection: $input.interestType) {
                ForEach(InterestType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .glassSurface(cornerRadius: 14)

            LabeledContent("年利") {
                HStack(spacing: 6) {
                    TextField(
                        "1.5",
                        value: $input.annualRatePercent,
                        format: .number.precision(.fractionLength(0...3))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("loan-rate-field")
                    Text("％")
                        .foregroundStyle(.secondary)
                }
            }

            if input.interestType == .variable {
                rateHistoryRows
            }
        } header: {
            Text("金利")
        } footer: {
            if input.interestType == .variable {
                Text("見直しがあったら、その適用月と新しい年利を足してください。先の利率は予測しません。")
            }
        }
        .glassListRow()
    }

    /// 変動金利の見直し履歴です。`LoanRateChange` は不変の値なので、編集は作り直しで行います。
    @ViewBuilder
    private var rateHistoryRows: some View {
        ForEach(Array(input.rateHistory.enumerated()), id: \.offset) { index, change in
            HStack {
                DatePicker(
                    "適用開始",
                    selection: rateHistoryDate(at: index),
                    displayedComponents: .date
                )
                .labelsHidden()
                Spacer(minLength: 8)
                TextField(
                    "1.5",
                    value: rateHistoryPercent(at: index),
                    format: .number.precision(.fractionLength(0...3))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
                Text("％")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(
                "\(change.effectiveFrom.formatted(.dateTime.year().month()))からの年利"
            )
        }
        .onDelete { offsets in
            input.rateHistory.remove(atOffsets: offsets)
        }

        Button {
            input.rateHistory.append(
                LoanRateChange(
                    effectiveFrom: .now,
                    annualRatePercent: input.annualRatePercent
                )
            )
        } label: {
            Label("利率の見直しを追加", systemImage: "plus.circle")
                .frame(minHeight: 44)
        }
    }

    /// リボ払いの残高スライドです。**元金が減らない帯は保存時に弾かれます。**
    var revolvingSection: some View {
        Section {
            ForEach(Array(input.slidingTiers.enumerated()), id: \.offset) { index, tier in
                HStack {
                    TextField(
                        "500,000",
                        value: slidingTierUpperBalance(at: index),
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    Text("円以下なら")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "15,000",
                        value: slidingTierMonthlyPayment(at: index),
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    Text("円")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(
                    "残高\(tier.upperBalance.formatted())円以下のときの毎月の返済額"
                )
            }
            .onDelete { offsets in
                input.slidingTiers.remove(atOffsets: offsets)
            }

            Button {
                input.slidingTiers.append(
                    RevolvingTier(upperBalance: 0, monthlyPayment: 0)
                )
            } label: {
                Label("残高の段を追加", systemImage: "plus.circle")
                    .frame(minHeight: 44)
            }
        } header: {
            Text("残高スライド")
        } footer: {
            Text("残高がその金額以下のときの、毎月の返済額です。利息を下回る額にすると残高が減らないため保存できません。")
        }
        .glassListRow()
    }

    var scheduleSection: some View {
        Section {
            Picker("毎月の返済日", selection: $input.paymentDay) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)日").tag(day)
                }
            }
            .accessibilityIdentifier("loan-payment-day-picker")
        } footer: {
            Text("返済日の当日に、返済できたかを確認する通知を出します。")
        }
        .glassListRow()
    }

    var bonusSection: some View {
        Section {
            amountField("ボーナス返済額", value: $input.bonusAmount, placeholder: "100,000")

            if input.bonusAmount > 0 {
                LabeledContent("上乗せする月") {
                    Text(bonusMonthsDescription)
                        .foregroundStyle(.secondary)
                }
                monthPicker
            }
        } header: {
            Text("ボーナス返済")
        } footer: {
            Text("上乗せぶんは全額が元金へ充当され、完済が早まります。")
        }
        .glassListRow()
    }

    /// 月の複数選択です。`Picker` は複数選択に対応していないため、ボタンを並べています。
    private var monthPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(bonusMonthOptions, id: \.self) { month in
                let isSelected = input.bonusMonths.contains(month)
                Button {
                    if isSelected {
                        input.bonusMonths.removeAll { $0 == month }
                    } else {
                        input.bonusMonths = (input.bonusMonths + [month]).sorted()
                    }
                } label: {
                    Text("\(month)")
                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.22) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(month)月")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var bonusMonthsDescription: String {
        guard !input.bonusMonths.isEmpty else { return "未選択" }
        return input.bonusMonths.map { "\($0)月" }.joined(separator: "・")
    }

    /// 入力中の試算です。**保存前に毎月いくらかが分かる**ようにしています。
    @ViewBuilder
    var previewSection: some View {
        if let schedule = previewSchedule, let first = schedule.installments.first {
            Section("この条件での試算") {
                LabeledContent("毎月の返済額") {
                    Text(first.amount, format: .currency(code: "JPY").precision(.fractionLength(0)))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                LabeledContent("返済回数", value: "\(schedule.paymentCount)回")
                if let completionDate = schedule.completionDate {
                    LabeledContent("完済予定") {
                        Text(completionDate, format: .dateTime.year().month())
                    }
                }
                LabeledContent("利息の合計") {
                    Text(
                        schedule.totalInterest,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                    .monospacedDigit()
                }
            }
            .glassListRow()
        }
    }

    @ViewBuilder
    var validationSection: some View {
        if let validationMessage {
            Section {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityFocused($isValidationFocused)
                    .accessibilityIdentifier("loan-validation-message")
            }
            .glassListRow()
        }
    }

    // MARK: - 入力部品

    private func amountField(
        _ title: String,
        value: Binding<Double>,
        placeholder: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text("¥")
                    .foregroundStyle(.secondary)
                TextField(
                    placeholder,
                    value: value,
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            }
        }
    }

    private func countField(_ title: String, value: Binding<Int>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("12", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("回")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 不変の値への束縛

    /// `LoanRateChange` と `RevolvingTier` は不変の値です。
    /// 編集させるために、setterで作り直す `Binding` を用意しています。
    private func rateHistoryDate(at index: Int) -> Binding<Date> {
        Binding(
            get: { input.rateHistory[index].effectiveFrom },
            set: { newValue in
                input.rateHistory[index] = LoanRateChange(
                    effectiveFrom: newValue,
                    annualRatePercent: input.rateHistory[index].annualRatePercent
                )
            }
        )
    }

    private func rateHistoryPercent(at index: Int) -> Binding<Double> {
        Binding(
            get: { input.rateHistory[index].annualRatePercent },
            set: { newValue in
                input.rateHistory[index] = LoanRateChange(
                    effectiveFrom: input.rateHistory[index].effectiveFrom,
                    annualRatePercent: newValue
                )
            }
        )
    }

    private func slidingTierUpperBalance(at index: Int) -> Binding<Double> {
        Binding(
            get: { input.slidingTiers[index].upperBalance },
            set: { newValue in
                input.slidingTiers[index] = RevolvingTier(
                    upperBalance: newValue,
                    monthlyPayment: input.slidingTiers[index].monthlyPayment
                )
            }
        )
    }

    private func slidingTierMonthlyPayment(at index: Int) -> Binding<Double> {
        Binding(
            get: { input.slidingTiers[index].monthlyPayment },
            set: { newValue in
                input.slidingTiers[index] = RevolvingTier(
                    upperBalance: input.slidingTiers[index].upperBalance,
                    monthlyPayment: newValue
                )
            }
        )
    }
}
