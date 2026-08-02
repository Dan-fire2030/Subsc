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

    var id: Int { period }
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

    /// 実際に支払いが発生する回数です。滞納した月は数えません。
    var paymentCount: Int {
        installments.filter { !$0.isMissed }.count
    }

    static let empty = LoanSchedule(installments: [])
}
