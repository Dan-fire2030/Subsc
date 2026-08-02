import Foundation

/// 契約と返済実績から、一覧行と詳細画面が必要とする値をまとめて出します。
///
/// **ビューに計算を書かないための型**です。残高も完済予定日も予定表から導かれるため、
/// 画面ごとに導き方を書くと表示が食い違います。導き方はここ1箇所に閉じます。
struct LoanSummary: Equatable {
    /// 進捗の母数です。「今の残高から」登録した場合は開始残高になります。
    let startingPrincipal: Double
    /// 直近の実績時点の残高です。**まだ来ていない回は数えません。**
    let currentBalance: Double
    let nextDueDate: Date?
    /// 次回の返済額です。返す回が無ければ0です。
    let nextAmount: Double
    let completionDate: Date?
    /// これから返す回数です。
    let remainingCount: Int
    let totalCount: Int
    let totalInterest: Double
    let missedCount: Int
    let isCompleted: Bool

    /// これまでに減らせた元金です。滞納で残高が増えていてもマイナスにはしません。
    var repaidPrincipal: Double {
        max(0, startingPrincipal - currentBalance)
    }

    /// 0〜1の進捗です。**元本が0（未入力）のときに0除算しないよう分岐しています。**
    var progress: Double {
        guard startingPrincipal > 0 else { return isCompleted ? 1 : 0 }
        if isCompleted { return 1 }
        return min(1, max(0, repaidPrincipal / startingPrincipal))
    }
}

extension LoanSummary {
    /// 保存済みの返済記録から組み立てます。
    ///
    /// **「まだ来ていない回」は `scheduled` です。** 返済日を過ぎた回は
    /// `LoanPaymentStore.settlePastDue` が返済済みへ移すため、ここは状態だけを見て
    /// 過去と未来を分けます。日付を見ないので、実行日に結果が揺れません。
    static func make(for loan: Loan) -> LoanSummary {
        let payments = LoanPaymentStore.sortedPayments(on: loan)
        let startingPrincipal = loan.origin == .fromCurrentBalance
            ? loan.startingBalance
            : loan.originalPrincipal
        let settled = payments.filter { $0.status != .scheduled }
        let upcoming = payments.filter { $0.status == .scheduled }

        return LoanSummary(
            startingPrincipal: startingPrincipal,
            currentBalance: settled.last?.balanceAfter ?? startingPrincipal,
            nextDueDate: upcoming.first?.dueOn,
            nextAmount: upcoming.first?.scheduledAmount ?? 0,
            completionDate: payments.last?.dueOn,
            remainingCount: upcoming.count,
            totalCount: payments.count,
            totalInterest: payments.reduce(0) { $0 + $1.interestPortion },
            missedCount: payments.filter { $0.status == .missed }.count,
            // 予定表を作る前（記録が1件も無い状態）を完済と誤認しないようにします。
            isCompleted: loan.isClosed || (!payments.isEmpty && upcoming.isEmpty)
        )
    }
}
