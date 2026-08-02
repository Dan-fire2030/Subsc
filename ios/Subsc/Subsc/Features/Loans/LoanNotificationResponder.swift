import Foundation
import SwiftData
import UserNotifications

/// 通知のボタンで選ばれた「返済した」「滞納」を保存へ反映します。
///
/// **アプリを開かずに記録できるようにするための受け口です。**
/// 読み解きは `LoanNotificationResponse` が担い、ここは保存だけを行います。
/// **デリゲートのメソッドは MainActor から呼ばれる保証がありません。**
/// `@unchecked Sendable` にしているのは、保持しているのが Sendable な `ModelContainer` だけで、
/// 保存はすべて MainActor 上で行うためです。
final class LoanNotificationResponder: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    /// アプリを開いている最中でも通知を出します。返済日の確認は見逃されると意味がないためです。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // **文字列だけを取り出してから MainActor へ渡します。**
        // 通知そのものは Sendable ではないため、アクターをまたげません。
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier

        guard let parsed = LoanNotificationResponse(
            identifier: identifier,
            actionIdentifier: actionIdentifier
        ) else { return }

        await MainActor.run { apply(parsed) }
    }

    /// 応答を該当の契約へ反映します。
    ///
    /// 保存に失敗しても**通知の受け取りは止めません。** 次回アプリを開いたときに
    /// 予定表を組み直せば、記録が1件欠けるだけで整合は保たれます。
    @MainActor
    func apply(_ response: LoanNotificationResponse) {
        let context = modelContainer.mainContext
        let clientID = response.clientID
        let descriptor = FetchDescriptor<Loan>(
            predicate: #Predicate { $0.clientID == clientID }
        )

        guard
            let loan = try? context.fetch(descriptor).first,
            let payment = LoanPaymentStore.sortedPayments(on: loan)
                .first(where: { $0.periodKey == response.periodKey })
        else { return }

        do {
            switch response {
            case .paid:
                try LoanPaymentStore.recordPayment(
                    amount: payment.scheduledAmount,
                    period: payment.period,
                    on: loan
                )
            case .missed:
                try LoanPaymentStore.markMissed(period: payment.period, on: loan)
            }
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
