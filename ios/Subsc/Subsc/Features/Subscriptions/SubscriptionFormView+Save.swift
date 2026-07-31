import SwiftData
import SwiftUI

/// 入力の検証と保存です。検証に失敗したら理由を日本語で示し、保存には進みません。
extension SubscriptionFormView {
    func save() async {
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
        target.costType = costType
        target.hasVariableAmount = hasVariableAmount
        target.paymentMethod = paymentMethod
        target.paymentMethodNote = paymentMethodNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        // 定額へ戻したときのために、変動費でも金額欄の値は保持しておきます。
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

        if hasVariableAmount {
            let now = Date.now
            let components = Calendar.current.dateComponents([.year, .month], from: now)
            AmountEntryStore.record(
                amount: amount,
                year: components.year ?? 0,
                month: components.month ?? 0,
                on: target,
                recordedAt: now
            )
        }

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

    func showValidation(_ message: String) {
        validationMessage = message
        isValidationFocused = true
    }

    func isValidWebsiteURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return false
        }
        return true
    }
}
