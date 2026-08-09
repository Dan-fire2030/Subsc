import SwiftData
import SwiftUI

/// `DashboardView` の、保存を伴う操作です。
///
/// **どれも失敗しうるので、失敗したら `rollback` してから利用者に何が起きたかを伝えます。**
/// 中途半端に保存された状態を残さないためです。
extension DashboardView {
    /// 非表示の費目も次に表示した時点で正しい換算額にするため、全費目の為替レートを更新します。
    func refreshUsdExchangeRate() async {
        let dollarSubscriptions = subscriptions.filter { $0.currency == .usd }
        guard !dollarSubscriptions.isEmpty,
              let quote = try? await ExchangeRateService.usdJpy() else {
            return
        }

        let changedSubscriptions = dollarSubscriptions.filter {
            abs($0.exchangeRate - quote.rate) > 0.000_001
        }
        guard !changedSubscriptions.isEmpty else { return }

        for subscription in changedSubscriptions {
            subscription.exchangeRate = quote.rate
            subscription.updatedAt = .now
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "為替レートを保存できませんでした。"
        }
    }

    func toggleState(of subscription: Subscription) {
        withAnimation {
            subscription.state = subscription.state == .active ? .paused : .active
            subscription.updatedAt = .now
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "利用状況を保存できませんでした。"
            return
        }
        // 状態が変わると `RootView` の再同期が走るため、ここでは予約に触れません。
    }

    /// 借入の返済を止める・再開します。
    ///
    /// 再開では予定表を組み直すため失敗しうります。**失敗したら状態も戻します**
    /// （`rollback` が停止フラグごと巻き戻します）。中途半端に止まったままにしません。
    func togglePause(of loan: Loan) {
        do {
            if loan.isPaused {
                let result = try LoanPaymentStore.resume(loan: loan)
                for removed in result.removed {
                    modelContext.delete(removed)
                }
            } else {
                try LoanPaymentStore.pause(loan: loan)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = (error as? LocalizedError)?.errorDescription
                ?? "返済の停止状態を保存できませんでした。"
            return
        }
        // 停止したぶんの予約は、計画から消えることで `reconcile` が取り消します。
        Task {
            await NotificationService.reconcile(
                subscriptions: subscriptions,
                loans: loans,
                loanLead: loanNotificationSettings.lead,
                loanHour: loanNotificationSettings.hour
            )
        }
    }

    func delete(_ subscription: Subscription) {
        let clientID = subscription.clientID
        modelContext.delete(subscription)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "費目を削除できませんでした。"
            return
        }
        Task {
            await NotificationService.cancel(clientID: clientID)
        }
    }

    func confirmDeletion() {
        guard let pendingDeletion else { return }
        self.pendingDeletion = nil
        delete(pendingDeletion)
    }
}
