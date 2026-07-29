import SwiftData
import SwiftUI

struct SubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var registeredSubscriptions: [Subscription]

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
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var categoryError: String?
    @State private var isSaving = false
    @AccessibilityFocusState private var isValidationFocused: Bool

    private let initialDraft: Draft

    private let colorPresets = ["#007AFF", "#34C759", "#FF375F", "#AF52DE", "#FF9F0A"]
    private let dayOptions = [0, 1, 3, 7, 14, 30]
    private let hourOptions = [1, 3, 6, 12]

    private struct Draft: Equatable {
        let name: String
        let category: String
        let amount: Double
        let currency: SubscriptionCurrency
        let exchangeRate: Double
        let billingCycle: BillingCycle
        let state: SubscriptionState
        let renewalDate: Date
        let hasStartDate: Bool
        let startDate: Date
        let hasEndDate: Bool
        let endDate: Date
        let websiteURL: String
        let notes: String
        let colorHex: String
        let notificationsEnabled: Bool
        let notificationHour: Int
        let notificationMinute: Int
        let leadDays: [Int]
        let leadHours: [Int]
    }

    init(subscription: Subscription?) {
        self.subscription = subscription
        let calendar = Calendar.current
        let defaultNotificationTime = calendar.date(
            bySettingHour: subscription?.notificationHour ?? 9,
            minute: subscription?.notificationMinute ?? 0,
            second: 0,
            of: .now
        ) ?? .now
        let initialName = subscription?.name ?? ""
        let initialCategory = subscription?.category ?? "エンタメ"
        let initialAmount = subscription?.originalAmount ?? 0
        let initialCurrency = subscription?.currency ?? .jpy
        let initialExchangeRate = initialCurrency == .usd ? subscription?.exchangeRate ?? 0 : 0
        let initialBillingCycle = subscription?.billingCycle ?? .monthly
        let initialState = subscription?.state ?? .active
        let initialRenewalDate = subscription?.renewalDate ?? .now
        let initialHasStartDate = subscription?.startDate != nil
        let initialStartDate = subscription?.startDate ?? .now
        let initialHasEndDate = subscription?.endDate != nil
        let initialEndDate = subscription?.endDate ??
            calendar.date(byAdding: .year, value: 1, to: .now) ?? .now
        let initialWebsiteURL = subscription?.websiteURL ?? ""
        let initialNotes = subscription?.notes ?? ""
        let initialColorHex = ColorHex.canonical(subscription?.colorHex ?? "#007AFF")
        let initialNotificationsEnabled = subscription?.notificationsEnabled ?? true
        let initialLeadDays = Set(subscription?.leadDays ?? [1])
        let initialLeadHours = Set(subscription?.leadHours ?? [])
        let time = calendar.dateComponents([.hour, .minute], from: defaultNotificationTime)

        initialDraft = Draft(
            name: initialName,
            category: initialCategory,
            amount: initialAmount,
            currency: initialCurrency,
            exchangeRate: initialExchangeRate,
            billingCycle: initialBillingCycle,
            state: initialState,
            renewalDate: initialRenewalDate,
            hasStartDate: initialHasStartDate,
            startDate: initialStartDate,
            hasEndDate: initialHasEndDate,
            endDate: initialEndDate,
            websiteURL: initialWebsiteURL,
            notes: initialNotes,
            colorHex: initialColorHex,
            notificationsEnabled: initialNotificationsEnabled,
            notificationHour: time.hour ?? 9,
            notificationMinute: time.minute ?? 0,
            leadDays: initialLeadDays.sorted(),
            leadHours: initialLeadHours.sorted()
        )

        _name = State(initialValue: initialName)
        _category = State(initialValue: initialCategory)
        _amount = State(initialValue: initialAmount)
        _currency = State(initialValue: initialCurrency)
        _exchangeRate = State(initialValue: initialExchangeRate)
        _exchangeRateDate = State(initialValue: "")
        _exchangeRateStatus = State(initialValue: .idle)
        _billingCycle = State(initialValue: initialBillingCycle)
        _state = State(initialValue: initialState)
        _renewalDate = State(initialValue: initialRenewalDate)
        _hasStartDate = State(initialValue: initialHasStartDate)
        _startDate = State(initialValue: initialStartDate)
        _hasEndDate = State(initialValue: initialHasEndDate)
        _endDate = State(initialValue: initialEndDate)
        _websiteURL = State(initialValue: initialWebsiteURL)
        _notes = State(initialValue: initialNotes)
        _colorHex = State(initialValue: initialColorHex)
        _notificationsEnabled = State(initialValue: initialNotificationsEnabled)
        _notificationTime = State(initialValue: defaultNotificationTime)
        _leadDays = State(initialValue: initialLeadDays)
        _leadHours = State(initialValue: initialLeadHours)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                            .accessibilityFocused($isValidationFocused)
                            .accessibilityIdentifier("subscription-validation-message")
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
                    Button("保存") {
                        Task { await save() }
                    }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                        .accessibilityIdentifier("subscription-save-button")
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("新しいカテゴリ", isPresented: $isAddingCategory) {
                TextField("カテゴリ名", text: $newCategoryName)
                    .textInputAutocapitalization(.words)
                Button("追加") { addCategory() }
                Button("キャンセル", role: .cancel) { newCategoryName = "" }
            } message: {
                Text("\(CategoryCatalog.maxNameLength)文字以内で入力してください。")
            }
            .task(id: currency) {
                guard currency == .usd else { return }
                await loadExchangeRate()
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        currentDraft != initialDraft
    }

    /// プリセットと、登録済みサブスクが使っているカテゴリを合わせた選択肢です。
    private var categoryOptions: [String] {
        CategoryCatalog.options(
            usedCategories: registeredSubscriptions.map(\.category),
            selected: category
        )
    }

    /// プリセット5色に、プリセット外の現在色を加えた選択肢です。
    /// 選択中の値が選択肢に無いとPickerが空欄になるため、必ず含めます。
    private var colorOptions: [String] {
        let current = ColorHex.canonical(colorHex)
        return colorPresets.contains(current) ? colorPresets : colorPresets + [current]
    }

    /// `ColorPicker` は `Color` を扱うため、保存形式の16進数と相互変換します。
    private var customColor: Binding<Color> {
        Binding(
            get: { ColorHex.color(from: colorHex) },
            set: { colorHex = ColorHex.string(from: $0) }
        )
    }

    private func addCategory() {
        switch CategoryCatalog.validate(newCategoryName, existing: categoryOptions) {
        case .accepted(let name):
            category = name
            categoryError = nil
        case .failure(let message):
            categoryError = message
        }
        newCategoryName = ""
    }

    private var currentDraft: Draft {
        let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        return Draft(
            name: name,
            category: category,
            amount: amount,
            currency: currency,
            exchangeRate: exchangeRate,
            billingCycle: billingCycle,
            state: state,
            renewalDate: renewalDate,
            hasStartDate: hasStartDate,
            startDate: startDate,
            hasEndDate: hasEndDate,
            endDate: endDate,
            websiteURL: websiteURL,
            notes: notes,
            colorHex: colorHex,
            notificationsEnabled: notificationsEnabled,
            notificationHour: time.hour ?? 9,
            notificationMinute: time.minute ?? 0,
            leadDays: leadDays.sorted(),
            leadHours: leadHours.sorted()
        )
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showValidation("サービス名を入力してください。")
            return
        }
        guard amount >= 0 else {
            showValidation("料金は0以上で入力してください。")
            return
        }
        guard currency != .usd || exchangeRate > 0 else {
            showValidation("ドル円レートを取得してから保存してください。")
            return
        }
        if hasStartDate, hasEndDate, endDate < startDate {
            showValidation("終了日は開始日以降にしてください。")
            return
        }
        let trimmedWebsiteURL = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedWebsiteURL.isEmpty,
           !isValidWebsiteURL(trimmedWebsiteURL) {
            showValidation("公式サイトはhttpまたはhttpsのURLで入力してください。")
            return
        }

        isSaving = true
        defer { isSaving = false }
        if notificationsEnabled,
           !(await NotificationService.requestAuthorization()) {
            showValidation("通知が許可されていません。設定アプリで許可するか、通知をオフにしてください。")
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
        target.websiteURL = trimmedWebsiteURL
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
                await NotificationService.reschedule(for: target)
            }
            dismiss()
        } catch {
            modelContext.rollback()
            showValidation("保存できませんでした。もう一度お試しください。")
        }
    }

    private func showValidation(_ message: String) {
        validationMessage = message
        isValidationFocused = true
    }

    private func isValidWebsiteURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return false
        }
        return true
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
        switch ColorHex.canonical(hex) {
        case "#007AFF": "ブルー"
        case "#34C759": "グリーン"
        case "#FF375F": "ピンク"
        case "#AF52DE": "パープル"
        case "#FF9F0A": "オレンジ"
        default: "カスタム"
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
