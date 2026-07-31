import SwiftUI

/// `SubscriptionFormView` のフォーム各セクションです。
/// `body` から切り出しただけで、並び順・修飾子は元のまま保っています。
extension SubscriptionFormView {
    var serviceSection: some View {
        Section("サービス") {
            TextField("サービス名", text: $name)
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
        Section("料金") {
            Picker("通貨", selection: $currency) {
                ForEach(SubscriptionCurrency.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .glassSurface(cornerRadius: 14)

            LabeledContent("金額") {
                HStack(spacing: 6) {
                    Text(currency.symbol)
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("参照レート") {
                    if exchangeRateStatus == .loading {
                        ProgressView()
                            .controlSize(.small)
                    } else if exchangeRate > 0 {
                        Text("1 USD = \(exchangeRate.formatted(.currency(code: "JPY").precision(.fractionLength(2))))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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

            Picker("支払い周期", selection: $billingCycle) {
                ForEach(BillingCycle.allCases) { cycle in
                    Text(cycle.title).tag(cycle)
                }
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("iOSのローカル通知として、アプリを閉じている時も配信されます。")
        }
        .glassListRow()
    }

    var otherSection: some View {
        Section("その他") {
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
