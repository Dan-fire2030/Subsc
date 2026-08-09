import Foundation
import SwiftData
import UserNotifications

/// 通知のボタンで選ばれた「返済した」「滞納」を保存へ反映します。
///
/// **アプリを開かずに記録できるようにするための受け口です。**
/// 読み解きは `LoanNotificationResponse` が担い、ここは保存だけを行います。
///
/// ## デリゲートは完了ハンドラ版で実装する（2026-08-09の修正）
///
/// **`async` 版で書いてはいけません。** UIKitへ返す完了処理が関数の再開先、つまり
/// バックグラウンドスレッドから呼ばれ、
/// `-[UIApplication _updateSnapshotAndStateRestoration...]` のアサーションで
/// `SIGABRT` になります。**通知をタップするたびに落ちていました**（ビルド14で実機確認）。
///
/// **`await MainActor.run { }` を中に挟むだけでは直りません。** 関数自身の再開先が
/// メインでなければ、完了処理は結局バックグラウンドから呼ばれるためです。
/// また `@MainActor` を付けた `async` 版は、引数（`UNNotification` 等）が
/// Sendableでないためコンパイルが通りません。
///
/// 残る道が**完了ハンドラ版を実装し、ハンドラを自分でメインから呼ぶ**ことです。
///
/// 通知が一度も配信されていなかったため、この不具合は長く表に出ませんでした。
/// **配信が直った日に初めて発覚しています。**
final class LoanNotificationResponder: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    /// アプリを開いている最中でも通知を出します。返済日の確認は見逃されると意味がないためです。
    ///
    /// **完了ハンドラ版を実装します。** `async` 版だと、UIKitへ返す完了処理が
    /// 関数の再開先（バックグラウンド）から呼ばれます。ここは同期で返せるので、
    /// UIKitが呼んできたスレッドのまま即座に返します。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// 通知のボタンが押されたときの受け口です。
    ///
    /// **完了ハンドラは必ずメインで呼びます。** UIKitはこの完了処理でスナップショットと
    /// 状態復元を行い、メイン以外から呼ばれるとアサーションで落ちます
    /// （2026-08-09、`async` 版で実際に `SIGABRT` になりました）。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // **文字列だけを取り出してからアクターをまたぎます。**
        // 通知そのものは Sendable ではないため、そのままでは渡せません。
        // 読み解いた結果（`LoanNotificationResponse`）は文字列と整数だけなので渡せます。
        //
        // 更新日通知やリマインドをただ開いたときは、押されたボタンが合わずに `nil` になります。
        // 記録すべきことが無いだけなので、そのまま完了を返します。
        let parsed = LoanNotificationResponse(
            identifier: response.notification.request.identifier,
            actionIdentifier: response.actionIdentifier
        )

        // **完了ハンドラは Sendable ではありません。** UIKitから渡されるObjCのブロックで、
        // Swiftからは並行性の安全性を確かめられないためです。
        // ここで包むのは、**呼ぶのはこの1箇所・1回だけ**と読み切れるからです。
        let handler = UncheckedSendableBox(value: completionHandler)

        Task { @MainActor in
            if let parsed {
                apply(parsed)
            }
            handler.value()
        }
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

/// アクターをまたぐために、非Sendableな値を1つだけ包む入れ物です。
///
/// **安易に使ってはいけません。** ここで使うのは、UIKitから渡される完了ハンドラが
/// ObjCのブロックでSendableにできず、かつ**呼ぶ場所と回数を読み切れる**場合に限ります。
struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}
