import Foundation

/// 未保存の変更があるかを判定するための下書きです。
/// 初期値と現在値を丸ごと比較するため、フォームが扱う項目をそのまま並べています。
extension SubscriptionFormView {
    struct Draft: Equatable {
        let name: String
        let category: String
        let costType: CostType
        let hasVariableAmount: Bool
        let paymentMethod: PaymentMethod
        let paymentMethodNote: String
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

    var hasUnsavedChanges: Bool {
        currentDraft != initialDraft
    }

    var currentDraft: Draft {
        let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        return Draft(
            name: name,
            category: category,
            costType: costType,
            hasVariableAmount: hasVariableAmount,
            paymentMethod: paymentMethod,
            paymentMethodNote: paymentMethodNote,
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
}
