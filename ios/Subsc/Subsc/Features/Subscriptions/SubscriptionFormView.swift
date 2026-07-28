import SwiftData
import SwiftUI

struct SubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let subscription: Subscription?

    @State private var name: String
    @State private var category: String
    @State private var amount: Double
    @State private var currency: SubscriptionCurrency
    @State private var exchangeRate: Double
    @State private var exchangeRateDate: String
    @State private var exchangeRateStatus: ExchangeRateLoadStatus
    @State private var billingCycle: BillingCycle
    @State private var state: SubscriptionState
    @State private var renewalDate: Date
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var websiteURL: String
    @State private var notes: String
    @State private var colorHex: String
    @State private var notificationsEnabled: Bool
    @State private var notificationTime: Date
    @State private var leadDays: Set<Int>
    @State private var leadHours: Set<Int>
    @State private var validationMessage: String?

    private let categories = ["エンタメ", "仕事・学習", "音楽", "生活", "健康", "その他"]
    private let colors = ["#007AFF", "#34C759", "#FF375F", "#AF52DE", "#FF9F0A"]
    private let dayOptions = [0, 1, 3, 7, 14, 30]
    private let hourOptions = [1, 3, 6, 12]

    init(subscription: Subscription?) {
        self.subscription = subscription
        let calendar = Calendar.current
        let defaultNotificationTime = calendar.date(
            bySettingHour: subscription?.notificationHour ?? 9,
            minute: subscription?.notificationMinute ?? 0,
            second: 0,
            of: .now
        ) ?? .now

        _name = State(initialValue: subscription?.name ?? "")
        _category = State(initialValue: subscription?.category ?? "エンタメ")
        _amount = State(initialValue: subscription?.originalAmount ?? 0)
        _currency = State(initialValue: subscription?.currency ?? .jpy)
        _exchangeRate = State(initialValue: subscription?.currency == .usd ? subscription?.exchangeRate ?? 0 : 0)
        _exchangeRateDate = State(initialValue: "")
        _exchangeRateStatus = State(initialValue: .idle)
        _billingCycle = State(initialValue: subscription?.billingCycle ?? .monthly)
        _state = State(initialValue: subscription?.state ?? .active)
        _renewalDate = State(initialValue: subscription?.renewalDate ?? .now)
        _hasStartDate = State(initialValue: subscription?.startDate != nil)
        _startDate = State(initialValue: subscription?.startDate ?? .now)
        _hasEndDate = State(initialValue: subscription?.endDate != nil)
        _endDate = State(
            initialValue: subscription?.endDate ??
                calendar.date(byAdding: .year, value: 1, to: .now) ?? .now
        )
        _websiteURL = State(initialValue: subscription?.websiteURL ?? "")
        _notes = State(initialValue: subscription?.notes ?? "")
        _colorHex = State(initialValue: subscription?.colorHex ?? "#007AFF")
        _notificationsEnabled = State(initialValue: subscription?.notificationsEnabled ?? true)
        _notificationTime = State(initialValue: defaultNotificationTime)
        _leadDays = State(initialValue: Set(subscription?.leadDays ?? [1]))
        _leadHours = State(initialValue: Set(subscription?.leadHours ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("サービス") {
                    TextField("サービス名", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("カラー", selection: $colorHex) {
                        ForEach(colors, id: \.self) { hex in
                            Label {
                                Text(colorName(hex))
                            } icon: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 14, height: 14)
                            }
                            .tag(hex)
                        }
                    }
                }
                .glassListRow()

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

                Section("更新") {
                    DatePicker("次の更新日", selection: $renewalDate, displayedComponents: .date)
                    Picker("利用状況", selection: $state) {
                        ForEach(SubscriptionState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                }
                .glassListRow()

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

                Section("その他") {
                    TextField("公式サイト", text: $websiteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                .glassListRow()

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .glassListRow()
                }
            }
            .liquidGlassScreen()
            .navigationTitle(subscription == nil ? "サブスクを追加" : "登録内容を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .task(id: currency) {
                guard currency == .usd else { return }
                await loadExchangeRate()
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        !name.isEmpty || amount > 0
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "サービス名を入力してください。"
            return
        }
        guard amount >= 0 else {
            validationMessage = "料金は0以上で入力してください。"
            return
        }
        guard currency != .usd || exchangeRate > 0 else {
            validationMessage = "ドル円レートを取得してから保存してください。"
            return
        }
        if hasStartDate, hasEndDate, endDate < startDate {
            validationMessage = "終了日は開始日以降にしてください。"
            return
        }

        let target = subscription ?? Subscription(
            name: trimmedName,
            originalAmount: amount,
            renewalDate: renewalDate
        )
        if subscription == nil {
            modelContext.insert(target)
        }

        let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        target.name = trimmedName
        target.category = category
        target.originalAmount = amount
        target.currency = currency
        target.exchangeRate = currency == .usd ? exchangeRate : 1
        target.billingCycle = billingCycle
        target.state = state
        target.renewalDate = renewalDate
        target.startDate = hasStartDate ? startDate : nil
        target.endDate = hasEndDate ? endDate : nil
        target.websiteURL = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.colorHex = colorHex
        target.notificationsEnabled = notificationsEnabled
        target.notificationHour = time.hour ?? 9
        target.notificationMinute = time.minute ?? 0
        target.leadDays = Array(leadDays)
        target.leadHours = Array(leadHours)
        target.updatedAt = .now

        do {
            try modelContext.save()
            Task {
                if notificationsEnabled {
                    _ = await NotificationService.requestAuthorization()
                }
                await NotificationService.reschedule(for: target)
            }
            dismiss()
        } catch {
            validationMessage = "保存できませんでした。もう一度お試しください。"
        }
    }

    private func loadExchangeRate(forceRefresh: Bool = false) async {
        exchangeRateStatus = .loading
        do {
            let quote = try await ExchangeRateService.usdJpy(forceRefresh: forceRefresh)
            withAnimation(.easeOut(duration: 0.22)) {
                exchangeRate = quote.rate
                exchangeRateDate = quote.rateDate
                exchangeRateStatus = quote.isStale ? .stale : .loaded
            }
            if validationMessage == "ドル円レートを取得してから保存してください。" {
                validationMessage = nil
            }
        } catch {
            exchangeRateStatus = exchangeRate > 0 ? .stale : .failed
            if exchangeRate == 0 {
                validationMessage = error.localizedDescription
            }
        }
    }

    private func colorName(_ hex: String) -> String {
        switch hex {
        case "#007AFF": "ブルー"
        case "#34C759": "グリーン"
        case "#FF375F": "ピンク"
        case "#AF52DE": "パープル"
        default: "オレンジ"
        }
    }
}

private enum ExchangeRateLoadStatus: Equatable {
    case idle
    case loading
    case loaded
    case stale
    case failed
}

private struct NotificationTimingView: View {
    @Binding var leadDays: Set<Int>
    @Binding var leadHours: Set<Int>
    let dayOptions: [Int]
    let hourOptions: [Int]

    var body: some View {
        List {
            Section("日単位") {
                ForEach(dayOptions, id: \.self) { day in
                    Button {
                        toggle(day, in: &leadDays)
                    } label: {
                        HStack {
                            Text(day == 0 ? "当日" : "\(day)日前")
                                .foregroundStyle(.primary)
                            Spacer()
                            if leadDays.contains(day) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .glassListRow()

            Section("時間単位") {
                ForEach(hourOptions, id: \.self) { hour in
                    Button {
                        toggle(hour, in: &leadHours)
                    } label: {
                        HStack {
                            Text("\(hour)時間前")
                                .foregroundStyle(.primary)
                            Spacer()
                            if leadHours.contains(hour) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .glassListRow()
        }
        .liquidGlassScreen()
        .navigationTitle("通知タイミング")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ value: Int, in values: inout Set<Int>) {
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
    }
}
