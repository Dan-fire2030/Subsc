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

    // MARK: - アーカイブ

    /// 費目をアーカイブへ退けます。
    ///
    /// **状態（利用中／停止中）は書き換えません。** 復元したときに元の状態へ戻すためです。
    /// `archivedAt` を入れるだけで、一覧・レポート・カレンダーからは消えます。
    ///
    /// **確認は出しません**（30日は戻せるため）。代わりに「復元」で戻せる知らせを出します。
    func archive(_ subscription: Subscription) {
        let clientID = subscription.clientID
        withAnimation {
            subscription.archivedAt = .now
            subscription.updatedAt = .now
        }
        guard save(onFailure: "アーカイブできませんでした。") else { return }

        // **予約済みの通知を取り消します。** 一覧から消えたものの更新日が届くのはおかしいためです。
        Task {
            await NotificationService.cancel(clientID: clientID)
        }
        lastArchived = ArchivedNotice(subscription: subscription, loan: nil)
    }

    /// 借入をアーカイブへ退けます。**返済予定表は消しません**（消すと復元できなくなります）。
    func archive(_ loan: Loan) {
        withAnimation {
            loan.archivedAt = .now
            loan.updatedAt = .now
        }
        guard save(onFailure: "アーカイブできませんでした。") else { return }

        reconcileNotifications()
        lastArchived = ArchivedNotice(subscription: nil, loan: loan)
    }

    /// アーカイブから戻します。**元の状態（利用中／停止中）へそのまま戻ります。**
    /// アーカイブが状態を書き換えていないためです。
    func restore(_ subscription: Subscription) {
        withAnimation {
            subscription.archivedAt = nil
            subscription.updatedAt = .now
        }
        guard save(onFailure: "復元できませんでした。") else { return }
        reconcileNotifications()
    }

    func restore(_ loan: Loan) {
        withAnimation {
            loan.archivedAt = nil
            loan.updatedAt = .now
        }
        guard save(onFailure: "復元できませんでした。") else { return }
        reconcileNotifications()
    }

    /// アーカイブを空にします。**取り消せないため、呼ぶ前に必ず確認を取ります。**
    func deleteAllArchived() {
        let archivedSubscriptions = subscriptions.filter { ArchivePolicy.isArchived($0.archivedAt) }
        let archivedLoans = loans.filter { ArchivePolicy.isArchived($0.archivedAt) }
        let clientIDs = archivedSubscriptions.map(\.clientID)

        withAnimation {
            for subscription in archivedSubscriptions {
                modelContext.delete(subscription)
            }
            for loan in archivedLoans {
                modelContext.delete(loan)
            }
        }
        guard save(onFailure: "アーカイブを空にできませんでした。") else { return }

        Task {
            for clientID in clientIDs {
                await NotificationService.cancel(clientID: clientID)
            }
        }
        reconcileNotifications()
    }

    /// アーカイブ欄の行をまとめて扱うための入口です。費目と借入で呼び分けます。
    func restoreItem(_ item: DashboardListItem) {
        switch item {
        case .subscription(let subscription): restore(subscription)
        case .loan(let loan, _): restore(loan)
        }
    }

    func confirmArchiveDeletion() {
        guard let pendingArchiveDeletion else { return }
        self.pendingArchiveDeletion = nil

        switch pendingArchiveDeletion {
        case .subscription(let subscription):
            delete(subscription)
        case .loan(let loan, _):
            modelContext.delete(loan)
            guard save(onFailure: "借入を削除できませんでした。") else { return }
            reconcileNotifications()
        }
    }

    /// 期限を過ぎたアーカイブを消します。
    ///
    /// **起動時とアーカイブ欄を開いたときの両方から呼びます。**
    /// 消すものが1件も無ければ保存もしないので、無用な同期は起きません。
    func removeExpiredArchives() {
        do {
            let removed = try ArchiveCleaner.removeExpired(
                subscriptions: subscriptions,
                loans: loans,
                context: modelContext
            )
            guard removed > 0 else { return }
            reconcileNotifications()
        } catch {
            modelContext.rollback()
            operationError = "期限切れのアーカイブを削除できませんでした。"
        }
    }

    /// 保存し、失敗したら巻き戻して知らせます。
    ///
    /// **同じ書き方が5箇所に並んだのでまとめました。** 巻き戻しを1箇所でも忘れると、
    /// 画面と保存内容が食い違ったまま進みます。
    private func save(onFailure message: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            operationError = message
            return false
        }
    }

    private func reconcileNotifications() {
        Task {
            await NotificationService.reconcile(
                subscriptions: subscriptions,
                loans: loans,
                loanLead: loanNotificationSettings.lead,
                loanHour: loanNotificationSettings.hour
            )
        }
    }
}

/// アーカイブ直後に出す知らせです。**「復元」で戻せることをその場で伝えます。**
/// 確認を出さない代わりに、取り消しの手段を目の前に置いています。
struct ArchivedNotice: Identifiable {
    let id = UUID()
    let subscription: Subscription?
    let loan: Loan?

    var name: String {
        subscription?.name ?? loan?.name ?? ""
    }
}
