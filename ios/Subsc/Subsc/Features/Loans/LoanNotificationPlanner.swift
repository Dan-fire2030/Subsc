import Foundation

/// 返済日当日に出す通知の、種類と応答の定義です。
///
/// **通知の上で「返済した」「滞納」を選べるようにします。** 返済日にアプリを開いてもらう前提だと、
/// 記録が抜けて予定表が実態とずれます。開かずに答えられる形にしておきます。
enum LoanNotificationAction: String, CaseIterable {
    case paid = "loan-paid"
    case missed = "loan-missed"

    /// 通知に並ぶボタンの文言です。
    var title: String {
        switch self {
        case .paid: "返済した"
        case .missed: "滞納"
        }
    }

    /// 通知の分類です。この識別子でボタンの組が決まります。
    static let categoryIdentifier = "loan-payment"
}

/// 返済日の通知を組み立てます。
///
/// 先の回まで予約しておくのは、アプリを開かない月があっても通知が届くようにするためです。
/// 完済済み・滞納として記録済みの回は計画から外れ、再スケジュール時に取り消されます。
enum LoanNotificationPlanner {
    /// 何ヶ月先まで予約しておくか。長くすると予約枠を食い、更新日通知を圧迫します。
    static let monthsAhead = 3

    /// 通知を出す時刻の既定値です。設定が渡されないときに使います。
    ///
    /// **返済日は年月日しか持たないため、そのまま使うと0時に鳴ります。**
    /// 深夜の通知は気づかれないか、寝ているところを起こすだけです。
    static let notificationHour = LoanNotificationSettings.Defaults.hour

    static func plannedPayments(
        loans: [Loan],
        now: Date,
        limit: Int,
        lead: LoanNotificationLead = LoanNotificationSettings.Defaults.lead,
        hour: Int = LoanNotificationSettings.Defaults.hour,
        calendar: Calendar = .current
    ) -> [NotificationService.PlannedNotification] {
        guard limit > 0 else { return [] }

        let planned = loans
            // 停止中は返済日が来ても払わないので、通知しません。
            // 再開すると予定表が組み直され、次の計画で予約し直されます。
            .filter { !$0.isClosed && !$0.isPaused }
            .flatMap { loan in
                upcomingPayments(on: loan, now: now, calendar: calendar).compactMap {
                    notification(
                        for: loan,
                        payment: $0,
                        now: now,
                        lead: lead,
                        hour: hour,
                        calendar: calendar
                    )
                }
            }

        return planned
            .sorted { $0.date == $1.date ? $0.identifier < $1.identifier : $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }

    /// これから返済日を迎える回のうち、まだ記録が付いていないものです。
    private static func upcomingPayments(
        on loan: Loan,
        now: Date,
        calendar: Calendar
    ) -> [LoanPayment] {
        guard let horizon = calendar.date(byAdding: .month, value: monthsAhead, to: now) else {
            return []
        }
        return LoanPaymentStore.sortedPayments(on: loan).filter { payment in
            guard payment.status == .scheduled, let dueOn = payment.dueOn else { return false }
            // **ここで「返済日が今より後か」を見てはいけません。**
            // 返済日は0時なので、当日の0〜9時に開くと当日ぶんが「もう過ぎた」と判定され、
            // その日の通知が予約されませんでした。過去かどうかは、返済日ではなく
            // 実際に鳴る時刻で判断する必要があるため、通知を組み立てる側へ寄せています。
            return dueOn <= horizon
        }
    }

    private static func notification(
        for loan: Loan,
        payment: LoanPayment,
        now: Date,
        lead: LoanNotificationLead,
        hour: Int,
        calendar: Calendar
    ) -> NotificationService.PlannedNotification? {
        guard
            let dueOn = payment.dueOn,
            let leadDate = calendar.date(byAdding: .day, value: -lead.rawValue, to: dueOn),
            // 返済日は0時なので、通知を出す時刻まで進めます。
            let firesAt = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: leadDate)
        else { return nil }

        // **何日前に寄せると、通知の時刻がもう過ぎていることがあります。**
        // 返済日そのものではなく、実際に鳴る時刻で判断しないと、
        // 過去日時の通知を予約して黙って捨てられます。
        guard firesAt > now else { return nil }

        let amount = payment.scheduledAmount
            .formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        let title = lead == .sameDay
            ? "\(loan.name)の返済日です"
            : "\(loan.name)の返済日が近づいています"
        let body = lead == .sameDay
            ? "\(amount)の返済予定です。返済できたか教えてください。"
            : "\(dueOn.formatted(.dateTime.month().day()))に\(amount)の返済予定です。"

        return NotificationService.PlannedNotification(
            clientID: loan.clientID,
            identifier: NotificationIdentifier.loanPayment(
                clientID: loan.clientID,
                periodKey: payment.periodKey
            ),
            date: firesAt,
            title: title,
            body: body,
            categoryIdentifier: LoanNotificationAction.categoryIdentifier
        )
    }
}

/// 通知への応答を、どの契約のどの回に対する何の操作かへ読み解きます。
///
/// **読み解きだけをここに置き、保存は呼び出し側に任せます。** 通知の受け取りは
/// アプリ本体の文脈が要るため、そのままではテストできません。判断だけを切り出しています。
enum LoanNotificationResponse: Equatable {
    case paid(clientID: String, periodKey: Int)
    case missed(clientID: String, periodKey: Int)

    /// 通知の識別子と、押されたボタンから応答を組み立てます。
    ///
    /// 識別子は `subsc-loan-<clientID>-<periodKey>` です。**clientID にハイフンが含まれる**ため、
    /// 末尾から年月を切り出します。前から分割すると UUID の途中で切れます。
    init?(identifier: String, actionIdentifier: String) {
        guard
            let action = LoanNotificationAction(rawValue: actionIdentifier),
            identifier.hasPrefix(NotificationNamespace.loan.prefix)
        else { return nil }

        let body = identifier.dropFirst(NotificationNamespace.loan.prefix.count)
        guard
            let separator = body.lastIndex(of: "-"),
            let periodKey = Int(body[body.index(after: separator)...])
        else { return nil }

        let clientID = String(body[..<separator])
        guard !clientID.isEmpty else { return nil }

        switch action {
        case .paid: self = .paid(clientID: clientID, periodKey: periodKey)
        case .missed: self = .missed(clientID: clientID, periodKey: periodKey)
        }
    }

    var clientID: String {
        switch self {
        case let .paid(clientID, _), let .missed(clientID, _): clientID
        }
    }

    var periodKey: Int {
        switch self {
        case let .paid(_, periodKey), let .missed(_, periodKey): periodKey
        }
    }
}
