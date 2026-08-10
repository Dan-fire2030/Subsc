import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    /// **iOSが1つのアプリに保持できる予約の数です。** 超えたぶんは例外にならず、黙って捨てられます。
    /// この数を超える計画を立ててはいけません。
    private static let maximumPendingRequests = 64
    /// 1つの費目について、何回先の更新まで予約しておくかです。
    ///
    /// **12から3へ減らしました（2026-08-09）。** 費目11件で候補が204件になり、
    /// 64件の枠を大きく食い潰していました。**先まで押さえても意味がありません。**
    /// アプリを開くたびに組み直すので、遠い将来の予約は他の費目の枠を奪うだけです。
    private static let renewalCyclesPerSubscription = 3
    /// 月末リマインドに割り当てる予約枠です。
    /// iOSの予約数には上限があるため、更新日通知を圧迫しないように取り分を決めています。
    private static let reminderBudget = 16

    struct SyncResult: Equatable {
        let scheduled: Int
        let failed: Int
        /// 予約したはずなのに、読み戻したら入っていなかった件数です。
        ///
        /// **上限超過は例外になりません。** `add` は成功を返したまま、iOS側が黙って捨てます。
        /// 数えて返さないと、通知が来ないことに誰も気づけません（実際に気づけませんでした）。
        let missing: Int

        init(scheduled: Int, failed: Int, missing: Int = 0) {
            self.scheduled = scheduled
            self.failed = failed
            self.missing = missing
        }
    }

    struct PlannedNotification: Equatable {
        let clientID: String
        let identifier: String
        let date: Date
        let title: String
        let body: String
        /// 通知に並べるボタンの組です。既定の nil はボタンなしを意味します。
        let categoryIdentifier: String?

        init(
            clientID: String,
            identifier: String,
            date: Date,
            title: String,
            body: String,
            categoryIdentifier: String? = nil
        ) {
            self.clientID = clientID
            self.identifier = identifier
            self.date = date
            self.title = title
            self.body = body
            self.categoryIdentifier = categoryIdentifier
        }
    }

    /// ローンの返済日通知に割り当てる予約枠です。
    private static let loanBudget = 12

    /// 通知に並べるボタンを登録します。**予約より先に済ませないとボタンが出ません。**
    static func registerCategories() {
        let actions = LoanNotificationAction.allCases.map {
            UNNotificationAction(identifier: $0.rawValue, title: $0.title, options: [])
        }
        let category = UNNotificationCategory(
            identifier: LoanNotificationAction.categoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // **1つの費目だけを予約し直す口は廃止しました（2026-08-09）。**
    // 全体の枠（64件）を見ずにその費目のぶんを積み増すため、枠が埋まっている端末では
    // 追加したぶんが黙って捨てられていました。**費目を1件足した直後の通知が届かない**
    // という不具合の原因です。保存・記録・停止のどの操作でも `updatedAt` か `stateRaw` が
    // 変わるので、`RootView` の再同期（`reconcile`）が必ず走ります。そちらへ一本化します。

    static func reconcile(
        subscriptions: [Subscription],
        loans: [Loan] = [],
        loanLead: LoanNotificationLead = LoanNotificationSettings.Defaults.lead,
        loanHour: Int = LoanNotificationSettings.Defaults.hour,
        now: Date = .now
    ) async -> SyncResult {
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        // リマインドを先に確保し、残りの枠を更新日通知へ回します。
        let reminders = ReminderPlanner.plannedReminders(
            subscriptions: subscriptions,
            now: now,
            limit: reminderBudget
        )
        let loanPayments = LoanNotificationPlanner.plannedPayments(
            loans: loans,
            now: now,
            limit: loanBudget,
            lead: loanLead,
            hour: loanHour
        )
        let renewals = plannedNotifications(
            subscriptions: subscriptions,
            now: now,
            limit: maximumPendingRequests - reminders.count - loanPayments.count
        )
        let pendingIdentifiers = pending.map(\.identifier)
        // 名前空間ごとに掃除します。まとめて消すと、片方の再スケジュールが
        // もう片方の予約を巻き添えにします。
        let obsoleteIdentifiers = NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(renewals.map(\.identifier)),
            in: .renewal
        ) + NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(reminders.map(\.identifier)),
            in: .reminder
        ) + NotificationIdentifier.obsolete(
            pending: pendingIdentifiers,
            desired: Set(loanPayments.map(\.identifier)),
            in: .loan
        )

        // **消してから足します（2026-08-09に順序を入れ替えました）。**
        // 逆にすると、その瞬間だけ「古い予約＋新しい予約」を同時に抱えることになり、
        // 64件を超えたぶんが黙って捨てられます。**新しく足した費目の通知が消える**
        // 原因でした。先に空けてから入れれば、抱える数が上限を超えません。
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)

        let planned = renewals + reminders + loanPayments
        let result = await add(notifications: planned)
        guard !Task.isCancelled else { return result }

        // **入ったことを読み戻して確かめます。** 上限超過は例外にならないため、
        // 数えないと「予約したつもりで届かない」に気づけません。
        let missing = await missingCount(desired: Set(planned.map(\.identifier)))
        return SyncResult(scheduled: result.scheduled, failed: result.failed, missing: missing)
    }

    /// 予約したはずの識別子のうち、実際には入っていなかった件数です。
    ///
    /// **許可されていないときは数えません（2026-08-10に追加）。**
    /// 許可が無いと予約は保持されず、読み戻すと全件が「欠けている」と数えられます。
    /// そのまま知らせると、**上限超過でもないのに「通知タイミングを減らせ」と案内**して
    /// しまい、原因と無関係な対処へ誘導します（実際にシミュレーターで54件と出ました）。
    ///
    /// 許可が無いこと自体は設定画面が扱うため、ここでは黙って0を返します。
    private static func missingCount(desired: Set<String>) async -> Int {
        guard !desired.isEmpty else { return 0 }

        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        // `.provisional` は静かに届く許可なので、予約は保持されます。数える対象に含めます。
        guard status == .authorized || status == .provisional else { return 0 }

        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))
        return desired.subtracting(pending).count
    }

    /// 費目を削除したときに、その費目の予約を取り消します。
    /// 更新日通知とリマインドの**両方**が対象です。片方だけ消すと、消えた費目の通知が届き続けます。
    static func cancel(clientID: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = NotificationIdentifier.all(
            pending: pending.map(\.identifier),
            clientID: clientID
        )
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func plannedNotifications(
        subscriptions: [Subscription],
        now: Date,
        limit: Int = maximumPendingRequests,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        guard limit > 0 else { return [] }

        var queues = subscriptions
            .filter { $0.notificationsEnabled && $0.state == .active }
            .map {
                notificationCandidates(for: $0, now: now, calendar: calendar)
                    .sorted { $0.date < $1.date }
            }
            .filter { !$0.isEmpty }
            .sorted {
                guard let lhs = $0.first, let rhs = $1.first else { return false }
                if lhs.date == rhs.date {
                    return lhs.clientID < rhs.clientID
                }
                return lhs.date < rhs.date
            }

        var result: [PlannedNotification] = []
        while result.count < limit {
            var addedInRound = false
            for index in queues.indices where result.count < limit {
                guard !queues[index].isEmpty else { continue }
                result.append(queues[index].removeFirst())
                addedInRound = true
            }
            if !addedInRound { break }
        }
        return result
    }

    private static func notificationCandidates(
        for subscription: Subscription,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        let renewalDates = subscription.upcomingRenewalDates(
            onOrAfter: now,
            limit: renewalCyclesPerSubscription,
            calendar: calendar
        )

        return renewalDates.flatMap { renewalDate -> [PlannedNotification] in
            guard let targetDate = renewalTargetDate(
                renewalDate: renewalDate,
                hour: subscription.notificationHour,
                minute: subscription.notificationMinute,
                calendar: calendar
            ) else { return [] }

            let cycleKey = targetDate.formatted(
                .iso8601.year().month().day().time(includingFractionalSeconds: false)
            )
            let offsets = leadOffsets(
                from: targetDate,
                leadDays: subscription.leadDays,
                leadHours: subscription.leadHours,
                calendar: calendar
            )

            return offsets.compactMap { suffix, date in
                guard date > now else { return nil }
                return PlannedNotification(
                    clientID: subscription.clientID,
                    identifier: NotificationIdentifier.renewal(
                        clientID: subscription.clientID,
                        cycleKey: cycleKey,
                        suffix: suffix
                    ),
                    date: date,
                    title: "\(subscription.name)の更新予定",
                    body: renewalBody(for: subscription, targetDate: targetDate)
                )
            }
        }
    }

    /// 更新日と通知時刻から、その回の基準時刻を組み立てます。
    private static func renewalTargetDate(
        renewalDate: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: renewalDate)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    /// 基準時刻から「何日前・何時間前」を引いた時刻の一覧です。
    private static func leadOffsets(
        from targetDate: Date,
        leadDays: [Int],
        leadHours: [Int],
        calendar: Calendar
    ) -> [(String, Date)] {
        leadDays.compactMap { day in
            calendar.date(byAdding: .day, value: -day, to: targetDate)
                .map { ("day-\(day)", $0) }
        } +
        leadHours.compactMap { hour in
            calendar.date(byAdding: .hour, value: -hour, to: targetDate)
                .map { ("hour-\(hour)", $0) }
        }
    }

    /// **その更新日について、これから予約できる通知時刻があるか**を返します。
    ///
    /// 過ぎた時刻は予約できないため、計画からは黙って外れます。
    /// 外れたこと自体を画面で知らせたいので、判定をここへ切り出しています。
    /// **知らせないと、「8/9の14時に、8/10更新・前日13:30で登録」したときに
    /// 通知がONのまま1件も予約されず、利用者は気づけません。**
    static func hasNotifiableTime(
        renewalDate: Date,
        hour: Int,
        minute: Int,
        leadDays: [Int],
        leadHours: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !leadDays.isEmpty || !leadHours.isEmpty else { return false }
        guard let targetDate = renewalTargetDate(
            renewalDate: renewalDate,
            hour: hour,
            minute: minute,
            calendar: calendar
        ) else { return false }

        return leadOffsets(
            from: targetDate,
            leadDays: leadDays,
            leadHours: leadHours,
            calendar: calendar
        )
        .contains { $0.1 > now }
    }

    /// 更新予告の本文です。
    ///
    /// **定額の費目は請求額を入れます。** 通知を開かずに「いくら出ていくか」が分かると、
    /// 支払いに備えるかどうかをその場で決められます。
    ///
    /// **変動費は金額を書きません。** 次回の請求額はまだ決まっておらず、
    /// 古い実績や見込みを断定して出すと、届いた通知そのものが誤りになります。
    ///
    /// 額は `yenAmount`（実際に請求される額）を使い、**月額へならしません**。
    /// 年払いを1/12にして通知すると、その日に引き落とされる額と食い違います。
    static func renewalBody(for subscription: Subscription, targetDate: Date) -> String {
        let dateText = targetDate.formatted(date: .abbreviated, time: .shortened)
        guard !subscription.hasVariableAmount else {
            return "\(dateText)に更新されます。"
        }
        let amountText = subscription.yenAmount.formatted(
            .currency(code: "JPY").precision(.fractionLength(0))
        )
        // **金額を主語にしません。** 「¥1,480 が更新されます」では、更新されるのが
        // 契約ではなく金額だと読めます。更新の事実を先に置き、額は添えます。
        return "\(dateText)に更新されます（\(amountText)）。"
    }

    private static func add(notifications: [PlannedNotification]) async -> SyncResult {
        let center = UNUserNotificationCenter.current()
        var scheduled = 0
        var failed = 0

        for notification in notifications {
            guard !Task.isCancelled else { break }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            if let categoryIdentifier = notification.categoryIdentifier {
                content.categoryIdentifier = categoryIdentifier
            }
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: notification.date
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notification.identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                failed += 1
            }
        }
        return SyncResult(scheduled: scheduled, failed: failed)
    }
}
