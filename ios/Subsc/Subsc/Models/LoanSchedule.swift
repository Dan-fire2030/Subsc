import Foundation

/// 返済予定表の1回分です。
struct LoanInstallment: Equatable, Identifiable {
    /// 1回目の返済日から数えて何ヶ月目かです。**滞納した月も1つ消費します。**
    ///
    /// 回数ではなく月の通し番号にしているのは、滞納で予定がずれても位置がぶれないようにするためです。
    let period: Int
    let dueDate: Date
    /// その月に実際に支払う額です。滞納した月は0になります。
    let amount: Double
    let principal: Double
    let interest: Double
    let balanceAfter: Double
    let isMissed: Bool
    /// 一時停止で飛ばした月です。**滞納（`isMissed`）と混同しないでください。**
    /// 滞納はその月の利息が残高へ繰り入れられますが、停止は利息そのものが発生しません。
    let isDeferred: Bool

    var id: Int { period }

    init(
        period: Int,
        dueDate: Date,
        amount: Double,
        principal: Double,
        interest: Double,
        balanceAfter: Double,
        isMissed: Bool = false,
        isDeferred: Bool = false
    ) {
        self.period = period
        self.dueDate = dueDate
        self.amount = amount
        self.principal = principal
        self.interest = interest
        self.balanceAfter = balanceAfter
        self.isMissed = isMissed
        self.isDeferred = isDeferred
    }
}

/// 返済予定表の全体です。
struct LoanSchedule: Equatable {
    let installments: [LoanInstallment]

    var totalInterest: Double {
        installments.reduce(0) { $0 + $1.interest }
    }

    var totalPayment: Double {
        installments.reduce(0) { $0 + $1.amount }
    }

    /// 完済日です。予定表が空のときだけ nil になります。
    var completionDate: Date? {
        installments.last?.dueDate
    }

    /// 実際に支払いが発生する回数です。滞納した月と停止中の月は数えません。
    var paymentCount: Int {
        installments.filter { !$0.isMissed && !$0.isDeferred }.count
    }

    static let empty = LoanSchedule(installments: [])
}
