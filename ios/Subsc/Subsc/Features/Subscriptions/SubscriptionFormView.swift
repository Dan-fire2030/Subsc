import SwiftData
import SwiftUI

/// サブスクの追加・編集フォームです。
///
/// 扱う項目が多く1ファイルに収まらないため、フォームの各セクション・カテゴリ/カラーの選択肢・
/// 未保存判定・保存処理・為替レート取得を `SubscriptionFormView+*.swift` へ分割しています。
/// 別ファイルのextensionから参照する必要があるため、保存プロパティの `private` は外しています
/// （Swiftのextensionはファイルをまたぐと `private` を参照できないため）。
struct SubscriptionFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var registeredSubscriptions: [Subscription]

    let subscription: Subscription?

    @State var name: String
    @State var category: String
    @State var amount: Double
    @State var currency: SubscriptionCurrency
    @State var exchangeRate: Double
    @State var exchangeRateDate: String
    @State var exchangeRateStatus: ExchangeRateLoadStatus
    @State var billingCycle: BillingCycle
    @State var state: SubscriptionState
    @State var renewalDate: Date
    @State var hasStartDate: Bool
    @State var startDate: Date
    @State var hasEndDate: Bool
    @State var endDate: Date
    @State var websiteURL: String
    @State var notes: String
    @State var colorHex: String
    @State var notificationsEnabled: Bool
    @State var notificationTime: Date
    @State var leadDays: Set<Int>
    @State var leadHours: Set<Int>
    @State var validationMessage: String?
    @State var isAddingCategory = false
    @State var newCategoryName = ""
    @State var categoryError: String?
    @State var isSaving = false
    @AccessibilityFocusState var isValidationFocused: Bool

    let initialDraft: Draft

    let colorPresets = ["#007AFF", "#34C759", "#FF375F", "#AF52DE", "#FF9F0A"]
    let dayOptions = [0, 1, 3, 7, 14, 30]
    let hourOptions = [1, 3, 6, 12]

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
                serviceSection
                priceSection
                renewalSection
                contractPeriodSection
                notificationSection
                otherSection
                validationSection
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
}
