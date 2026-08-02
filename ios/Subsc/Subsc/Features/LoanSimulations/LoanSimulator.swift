import Foundation

/// 試算の結果です。**「変える前」と「変えたあと」を必ず対で持ちます。**
///
/// 変えたあとの数字だけを見せても、得なのか損なのかが分かりません。差分を出すのがこの型の役目です。
struct LoanSimulationOutcome: Equatable {
    /// 何も変えなかった場合の予定表です。
    let baseline: LoanSchedule
    /// 変えたあとの予定表です。
    let simulated: LoanSchedule

    /// 減る利息です。**増える場合はマイナス**になります。
    var interestSaved: Double {
        baseline.totalInterest - simulated.totalInterest
    }

    /// 早まる回数です。**延びる場合はマイナス**になります。
    var monthsShortened: Int {
        baseline.paymentCount - simulated.paymentCount
    }

    /// 毎月の返済額です。リボ払いや繰上返済では回ごとに変わるため、1回目の額を指します。
    var baselineMonthlyPayment: Double {
        baseline.installments.first?.amount ?? 0
    }

    var simulatedMonthlyPayment: Double {
        simulated.installments.first?.amount ?? 0
    }

    var baselineCompletionDate: Date? { baseline.completionDate }
    var simulatedCompletionDate: Date? { simulated.completionDate }
}

/// 返済条件を変えたら何が起きるかを試算します。
///
/// **予定表の保存には一切触れません。** ここで作るのは「もしこうしたら」の使い捨ての予定表で、
/// 記録として残るものではありません。実際に繰上返済したときは返済履歴から記録します。
///
/// 収益化の方針（SPEC 8節）で**この3種はPro候補**です。1.0.0では無料で出しますが、
/// あとから切り出せるよう `Features/LoanSimulations/` に分けています。
enum LoanSimulator {
    /// 今の残高と残り回数から、**これからの返済だけ**を表す条件を作ります。
    ///
    /// 当初の条件で試算すると、すでに返し終えた回まで巻き込んで「早まる月数」が過大になります。
    static func remainingTerms(for loan: Loan, summary: LoanSummary) -> LoanTerms? {
        guard let nextDueDate = summary.nextDueDate, summary.currentBalance > 0 else {
            return nil
        }
        var terms = loan.terms(nextDueDate: nextDueDate)
        terms.principal = summary.currentBalance
        terms.installmentCount = summary.remainingCount
        return terms
    }

    /// 次の返済で上乗せしたときの効果です（期間短縮型）。
    ///
    /// 上乗せぶんは**全額が元金へ充当**されます。返済額は変わらず、回数が減ります。
    static func prepayment(
        of amount: Double,
        on terms: LoanTerms,
        calendar: Calendar = .current
    ) throws -> LoanSimulationOutcome {
        let calculator = LoanScheduleCalculator(calendar: calendar)
        return LoanSimulationOutcome(
            baseline: try calculator.schedule(for: terms),
            simulated: try calculator.schedule(for: terms, prepayments: [1: max(0, amount)])
        )
    }

    /// 金利が変わったときの効果です。
    ///
    /// **利率の見直し履歴は持ち込みません。** 履歴が残っていると、試算した新しい利率より
    /// 履歴のほうが優先され、変えたつもりの数字が出ません。
    static func rateChange(
        to annualRatePercent: Double,
        on terms: LoanTerms,
        calendar: Calendar = .current
    ) throws -> LoanSimulationOutcome {
        var changed = terms
        changed.annualRatePercent = annualRatePercent
        changed.rateChanges = []

        var baseline = terms
        baseline.rateChanges = []

        let calculator = LoanScheduleCalculator(calendar: calendar)
        return LoanSimulationOutcome(
            baseline: try calculator.schedule(for: baseline),
            simulated: try calculator.schedule(for: changed)
        )
    }

    /// まだ借りていない条件での試算です。**登録しなくても試せます。**
    static func estimate(
        _ terms: LoanTerms,
        calendar: Calendar = .current
    ) throws -> LoanSchedule {
        try LoanScheduleCalculator(calendar: calendar).schedule(for: terms)
    }
}
