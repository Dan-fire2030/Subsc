import Foundation
import SwiftData

/// 期限を過ぎたアーカイブを実際に消します。
///
/// **端末でアプリを開いたときにしか走りません。** バックグラウンドで消す仕組みは持っていないため、
/// 30日を過ぎても開かなければ残ります。これは仕様として受け入れている制約です。
///
/// 走らせる場所は2つ：**起動時**と**アーカイブ欄を開いたとき**。
/// 起動時だけだと、アプリを開きっぱなしで日をまたいだときに消えません。
enum ArchiveCleaner {
    /// 消す対象を選びます。**消す処理と分けているのは、ここだけテストできるようにするため**です。
    static func expired(
        subscriptions: [Subscription],
        loans: [Loan],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (subscriptions: [Subscription], loans: [Loan]) {
        (
            subscriptions.filter {
                ArchivePolicy.isExpired(archivedAt: $0.archivedAt, now: now, calendar: calendar)
            },
            loans.filter {
                ArchivePolicy.isExpired(archivedAt: $0.archivedAt, now: now, calendar: calendar)
            }
        )
    }

    /// 期限切れを消します。**1件も無ければ保存しません**（無用な同期を起こさないため）。
    ///
    /// - Returns: 消した件数。0なら何もしていません。
    @discardableResult
    static func removeExpired(
        subscriptions: [Subscription],
        loans: [Loan],
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> Int {
        let targets = expired(
            subscriptions: subscriptions,
            loans: loans,
            now: now,
            calendar: calendar
        )
        let count = targets.subscriptions.count + targets.loans.count
        guard count > 0 else { return 0 }

        for subscription in targets.subscriptions {
            context.delete(subscription)
        }
        for loan in targets.loans {
            context.delete(loan)
        }
        try context.save()
        return count
    }
}
