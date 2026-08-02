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

    static func plannedPayments(
        loans: [Loan],
        now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [NotificationService.PlannedNotification] {
        guard limit > 0 else { return [] }

        let planned = loans
            .filter { !$0.isClosed }
            .flatMap { loan in
                upcomingPayments(on: loan, now: now, calendar: calendar).compactMap {
                    notification(for: loan, payment: $0)
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
            return dueOn > now && dueOn <= horizon
        }
    }

    private static func notification(
        for loan: Loan,
        payment: LoanPayment
    ) -> NotificationService.PlannedNotification? {
        guard let dueOn = payment.dueOn else { return nil }
        let amount = payment.scheduledAmount
            .formatted(.currency(code: "JPY").precision(.fractionLength(0)))

        return NotificationService.PlannedNotification(
            clientID: loan.clientID,
            identifier: NotificationIdentifier.loanPayment(
                clientID: loan.clientID,
                periodKey: payment.periodKey
            ),
            date: dueOn,
            title: "\(loan.name)の返済日です",
            body: "\(amount)の返済予定です。返済できたか教えてください。",
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
