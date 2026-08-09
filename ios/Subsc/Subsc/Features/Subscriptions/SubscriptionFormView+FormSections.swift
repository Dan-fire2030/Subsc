import SwiftUI

/// `SubscriptionFormView` のフォーム各セクションです。
/// `body` から切り出しただけで、並び順・修飾子は元のまま保っています。
extension SubscriptionFormView {
    /// 変動費トグルの値です。
    ///
    /// 「利用者が自分で操作した」印は**このsetterでだけ**立てます。
    /// `onChange` で立てると、種別の変更にともなう自動提案まで操作扱いになり、
    /// 光熱費を選んだあとサブスクへ戻しても提案が働かなくなります。
    var variableAmountSelection: Binding<Bool> {
        Binding(
            get: { hasVariableAmount },
            set: { newValue in
                hasEditedVariableToggle = true
                hasVariableAmount = newValue
            }
        )
    }

    var serviceSection: some View {
        Section("費目") {
            // **新規登録のときだけ出します。** 編集中に出すと、名前・色・種別を
            // まとめて上書きすることになり、直したい1項目だけを触れなくなります。
            if subscription == nil {
                Button {
                    isChoosingService = true
                } label: {
                    Label("よく使うサービスから選ぶ", systemImage: "square.grid.2x2")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("choose-service-button")
            }

            Picker("種別", selection: $costType) {
                ForEach(CostType.subscriptionSelectable) { type in
                    Label(type.title, systemImage: type.systemImage).tag(type)
                }
            }
            .accessibilityIdentifier("subscription-cost-type-picker")

            TextField("費目名", text: $name)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("subscription-name-field")
            Picker("カテゴリ", selection: $category) {
                ForEach(categoryOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            Button {
                newCategoryName = ""
                categoryError = nil
                isAddingCategory = true
            } label: {
                Label("新しいカテゴリを追加", systemImage: "plus.circle")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("add-category-button")

            if let categoryError {
                Text(categoryError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("category-validation-message")
            }

            Picker("カラー", selection: $colorHex) {
                ForEach(colorOptions, id: \.self) { hex in
                    Label {
                        Text(colorName(hex))
                    } icon: {
                        Circle()
                            .fill(ColorHex.color(from: hex))
                            .frame(width: 14, height: 14)
                    }
                    .tag(hex)
                }
            }

            ColorPicker(
                "カラーを自由に選ぶ",
                selection: customColor,
                supportsOpacity: false
            )
        }
        .glassListRow()
    }

    var priceSection: some View {
        Section {
            Toggle("金額が毎月変わる", isOn: variableAmountSelection.animation())
                .accessibilityIdentifier("subscription-variable-amount-toggle")

            Picker("通貨", selection: $currency) {
                ForEach(SubscriptionCurrency.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .glassSurface(cornerRadius: 14)

            LabeledContent(hasVariableAmount ? "今月の金額" : "金額") {
                HStack(spacing: 6) {
                    Text(currency.symbol)
                        .foregroundStyle(BlackCatPalette.textMuted)
                    TextField(
                        currency == .usd ? "19.99" : "1,490",
                        value: $amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("subscription-amount-field")
                }
            }

            if currency == .usd {
                LabeledContent("円換算") {
                    if exchangeRate > 0 {
                        Text(
                            amount * exchangeRate,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    } else {
                        Text("取得待ち")
                            .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }

                LabeledContent("参照レート") {
                    if exchangeRateStatus == .loading {
                        ProgressView()
                            .controlSize(.small)
                    } else if exchangeRate > 0 {
                        Text("1 USD = \(exchangeRate.formatted(.currency(code: "JPY").precision(.fractionLength(2))))")
                            .font(.footnote)
                            .foregroundStyle(BlackCatPalette.textMuted)
                            .monospacedDigit()
                    } else {
                        Text("取得できません")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    Task { await loadExchangeRate(forceRefresh: true) }
                } label: {
                    Label("ドル円レートを更新", systemImage: "arrow.clockwise")
                        .frame(minHeight: 44)
                }
                .disabled(exchangeRateStatus == .loading)

                if !exchangeRateDate.isEmpty {
                    Text(
                        exchangeRateStatus == .stale
                            ? "\(exchangeRateDate)の保存済みレートを使用中"
                            : "\(exchangeRateDate)の参照レート"
                    )
                    .font(.caption)
                    .foregroundStyle(exchangeRateStatus == .stale ? .orange : .secondary)
                }
            }

            if !hasVariableAmount {
                Picker("支払い周期", selection: $billingCycle) {
                    ForEach(BillingCycle.allCases) { cycle in
                        Text(cycle.title).tag(cycle)
                    }
                }
            }
        } header: {
            Text("料金")
        } footer: {
            if hasVariableAmount {
                Text("入力した金額は今月の実績として記録されます。ほかの月は詳細画面から記録できます。")
            }
        }
        .glassListRow()
    }

    var renewalSection: some View {
        Section("更新") {
            DatePicker("次の更新日", selection: $renewalDate, displayedComponents: .date)
            Picker("利用状況", selection: $state) {
                ForEach(SubscriptionState.allCases) { state in
                    Text(state.title).tag(state)
                }
            }
        }
        .glassListRow()
    }

    var contractPeriodSection: some View {
        Section("契約期間") {
            Toggle("開始日を設定", isOn: $hasStartDate.animation())
            if hasStartDate {
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
            }
            Toggle("終了日を設定", isOn: $hasEndDate.animation())
            if hasEndDate {
                DatePicker(
                    "終了日",
                    selection: $endDate,
                    in: (hasStartDate ? startDate : .distantPast)...,
                    displayedComponents: .date
                )
            }
        }
        .glassListRow()
    }

    var notificationSection: some View {
        Section {
            Toggle("通知", isOn: $notificationsEnabled.animation())
            if notificationsEnabled {
                DatePicker(
                    "通知時刻",
                    selection: $notificationTime,
                    displayedComponents: .hourAndMinute
                )

                NavigationLink {
                    NotificationTimingView(
                        leadDays: $leadDays,
                        leadHours: $leadHours,
                        dayOptions: dayOptions,
                        hourOptions: hourOptions
                    )
                } label: {
                    LabeledContent("通知タイミング") {
                        Text("\(leadDays.count + leadHours.count)件")
                            .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }
            }
        } header: {
            Text("通知")
        } footer: {
            Text(notificationFooter)
        }
        .glassListRow()
    }

    /// 通知セクションの説明です。
    ///
    /// **直近の更新に間に合わない設定を、黙って受け取りません。**
    /// 過ぎた時刻は予約できないため計画から外れますが、画面は通知ONのままで、
    /// 利用者には何も起きていないように見えていました。
    var notificationFooter: String {
        let base = "iOSのローカル通知として、アプリを閉じている時も配信されます。"
        guard notificationsEnabled else { return base }

        let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        guard !NotificationService.hasNotifiableTime(
            renewalDate: renewalDate,
            hour: time.hour ?? 9,
            minute: time.minute ?? 0,
            leadDays: Array(leadDays),
            leadHours: Array(leadHours),
            now: .now
        ) else { return base }

        if leadDays.isEmpty, leadHours.isEmpty {
            return "\(base)\n\n通知タイミングが選ばれていないため、通知は届きません。"
        }
        return """
            \(base)

            この設定では、次の更新までに通知の時刻が過ぎているため、直近の1回は届きません。\
            通知タイミングを早めるか、通知時刻を先にしてください。次の更新以降は届きます。
            """
    }

    var otherSection: some View {
        Section("その他") {
            Picker("支払い方法", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            TextField("支払い方法の補足（例：◯◯カード）", text: $paymentMethodNote)
                .textInputAutocapitalization(.never)

            TextField("公式サイト", text: $websiteURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("メモ", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
        .glassListRow()
    }

    /// 入力エラーがあるときだけ表示する末尾のセクションです。
    @ViewBuilder
    var validationSection: some View {
        if let validationMessage {
            Section {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityFocused($isValidationFocused)
                    .accessibilityIdentifier("subscription-validation-message")
            }
            .glassListRow()
        }
    }
}
