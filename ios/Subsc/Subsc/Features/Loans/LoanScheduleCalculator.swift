import Foundation

/// 借入条件から返済予定表を組み立てます。
///
/// **ビューにも永続化にも依存しない純粋な計算**です。返済額は目視では正しさが分からず、
/// 間違っていても「それっぽい数字」が出てしまうため、ここだけを取り出してテストできる形にしています。
struct LoanScheduleCalculator {
    private let calendar: Calendar

    private enum Limit {
        /// 100年ぶん。ここに達したら設定の取り違えを疑い、無限ループにせず落とします。
        static let maximumPeriods = 1_200
        /// 円未満の端数は完済とみなします。浮動小数の誤差で残高が0.0000001残るのを避けます。
        static let settlement: Double = 0.5
    }

    /// テスト可能性のため、カレンダーは既定値付き引数で注入します。
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 毎月の返済額です。リボ払いは残高で変わるため、開始時点の残高に対する額を返します。
    func monthlyPayment(for terms: LoanTerms) throws -> Double {
        try validate(terms)
        return try basePayment(for: terms, balance: terms.principal, monthlyRate: monthlyRate(
            annualRatePercent: annualRatePercent(at: terms.firstDueDate, terms: terms)
        ))
    }

    /// 返済予定表を返します。
    ///
    /// - Parameters:
    ///   - missedPeriods: 滞納した月。1回目の返済日から数えた通し番号で指定します。
    ///   - prepayments: 繰上返済。通し番号と金額の対。**全額を元金へ充当**します（期間短縮型）。
    func schedule(
        for terms: LoanTerms,
        missedPeriods: Set<Int> = [],
        prepayments: [Int: Double] = [:]
    ) throws -> LoanSchedule {
        try validate(terms)

        var installments: [LoanInstallment] = []
        var balance = terms.principal
        var period = 1
        /// 実際に返済した回数です。**滞納した月は数えません。**
        /// 契約の回数に達したかどうかを、ずれた期間ではなくこの数で判断します。
        var settledCount = 0

        while balance > Limit.settlement {
            guard period <= Limit.maximumPeriods else {
                throw LoanTermsError.scheduleDoesNotTerminate
            }

            let dueDate = try dueDate(for: period, terms: terms)
            let rate = monthlyRate(annualRatePercent: annualRatePercent(at: dueDate, terms: terms))
            let interest = balance * rate

            if missedPeriods.contains(period) {
                // **返済せず、残高も減りません。** その月に発生した利息は残高へ繰り入れ、
                // 以降の返済で回収されます。遅延損害金は加算しません（SPEC 4-6）。
                balance += interest
                installments.append(
                    LoanInstallment(
                        period: period,
                        dueDate: dueDate,
                        amount: 0,
                        principal: 0,
                        interest: interest,
                        balanceAfter: balance,
                        isMissed: true
                    )
                )
                period += 1
                continue
            }

            let scheduled = try basePayment(for: terms, balance: balance, monthlyRate: rate)
            let extra = extraPayment(for: dueDate, period: period, terms: terms, prepayments: prepayments)

            // 契約の最後の回かどうか。リボ払いは回数を持たないため対象外です。
            //
            // **毎月の返済額は円未満を丸めているので、端数が必ず残ります。**
            // 残高で判定するだけだと、切り捨てられたぶんが最後に数円残り、
            // 契約より1回多い返済が生まれます（3回払いのはずが4回目に1円）。
            // 回数に達したら、残っている元金をその回へ寄せて必ず終わらせます。
            let isFinalInstallment = terms.method != .revolving
                && settledCount + 1 >= terms.installmentCount

            var principal = scheduled - interest + extra
            var amount = scheduled + extra
            if principal >= balance || isFinalInstallment {
                // 最終回。端数を元金へ寄せ、残高をちょうど0にします。
                principal = balance
                amount = principal + interest
            }
            balance -= principal
            settledCount += 1

            installments.append(
                LoanInstallment(
                    period: period,
                    dueDate: dueDate,
                    amount: amount,
                    principal: principal,
                    interest: interest,
                    balanceAfter: balance,
                    isMissed: false
                )
            )
            period += 1
        }

        return LoanSchedule(installments: installments)
    }

    // MARK: - 返済額

    private func basePayment(
        for terms: LoanTerms,
        balance: Double,
        monthlyRate rate: Double
    ) throws -> Double {
        switch terms.method {
        case .equalPayment:
            return Self.annuityPayment(
                principal: terms.principal,
                monthlyRate: monthlyRate(annualRatePercent: terms.annualRatePercent),
                count: terms.installmentCount
            )
        case .interestFree:
            return (terms.principal / Double(terms.installmentCount)).rounded()
        case .revolving:
            return try revolvingPayment(for: balance, terms: terms, monthlyRate: rate)
        }
    }

    /// 元利均等の毎月返済額です。`P * r / (1 - (1 + r)^-n)`。
    ///
    /// **`r == 0` で 0/0 になるため必ず分岐します。** 無利息の借入を元利均等で登録された場合に落ちます。
    private static func annuityPayment(principal: Double, monthlyRate rate: Double, count: Int) -> Double {
        guard rate > 0 else { return (principal / Double(count)).rounded() }
        let factor = pow(1 + rate, -Double(count))
        return (principal * rate / (1 - factor)).rounded()
    }

    /// リボ払いの定額です。**残高が収まる最小の帯**を選びます。どの帯にも収まらなければ最大の帯を使います。
    private func revolvingPayment(
        for balance: Double,
        terms: LoanTerms,
        monthlyRate rate: Double
    ) throws -> Double {
        let tiers = terms.revolvingTiers.sorted { $0.upperBalance < $1.upperBalance }
        guard let tier = tiers.first(where: { balance <= $0.upperBalance }) ?? tiers.last else {
            throw LoanTermsError.revolvingTiersMissing
        }

        // 利息が定額を食い尽くすと元金が減らず、完済予定日が無限になります。
        guard tier.monthlyPayment > balance * rate else {
            throw LoanTermsError.revolvingPaymentDoesNotReducePrincipal(balance: balance)
        }
        return tier.monthlyPayment
    }

    /// ボーナス返済と繰上返済の上乗せです。**どちらも全額が元金へ充当されます。**
    private func extraPayment(
        for dueDate: Date,
        period: Int,
        terms: LoanTerms,
        prepayments: [Int: Double]
    ) -> Double {
        var extra = prepayments[period] ?? 0
        let month = calendar.component(.month, from: dueDate)
        if terms.bonusAmount > 0, terms.bonusMonths.contains(month) {
            extra += terms.bonusAmount
        }
        return extra
    }

    // MARK: - 金利

    private func monthlyRate(annualRatePercent: Double) -> Double {
        annualRatePercent / 12 / 100
    }

    /// その返済日に適用される年利です。
    ///
    /// **未来の利率は予測しません。** 変更履歴のうち適用日が返済日以前で最も新しいものを使い、
    /// 該当が無ければ現在の利率が続く前提で計算します。
    private func annualRatePercent(at dueDate: Date, terms: LoanTerms) -> Double {
        let applicable = terms.rateChanges
            .filter { $0.effectiveFrom <= dueDate }
            .max { $0.effectiveFrom < $1.effectiveFrom }
        return applicable?.annualRatePercent ?? terms.annualRatePercent
    }

    // MARK: - 日付

    /// その回の返済日です。
    ///
    /// 月を進めたあと、**毎回あらためて返済日へ丸め直します。**
    /// 進めるだけだと、起点が短い月に丸められていた場合（31日指定で2月起点なら28日）、
    /// 以降ずっとその日で固定されてしまいます。
    private func dueDate(for period: Int, terms: LoanTerms) throws -> Date {
        guard let date = calendar.date(
            byAdding: .month,
            value: period - 1,
            to: terms.firstDueDate
        ) else {
            throw LoanTermsError.scheduleDoesNotTerminate
        }
        guard let paymentDay = terms.paymentDay else { return date }
        guard let adjusted = calendar.dueDate(inMonthOf: date, day: paymentDay) else {
            throw LoanTermsError.scheduleDoesNotTerminate
        }
        return adjusted
    }

    // MARK: - 入力検証

    private func validate(_ terms: LoanTerms) throws {
        guard terms.principal > 0 else {
            throw LoanTermsError.principalMustBePositive
        }
        guard terms.annualRatePercent >= 0 else {
            throw LoanTermsError.negativeInterestRate
        }
        // リボ払いは残高が尽きるまで続くため、回数を持ちません。
        if terms.method != .revolving {
            guard terms.installmentCount > 0 else {
                throw LoanTermsError.installmentCountMustBePositive
            }
        }
        if terms.method == .revolving {
            guard !terms.revolvingTiers.isEmpty else {
                throw LoanTermsError.revolvingTiersMissing
            }
        }
        if let month = terms.bonusMonths.first(where: { !(1...12).contains($0) }) {
            throw LoanTermsError.bonusMonthOutOfRange(month)
        }
        if terms.rateChanges.contains(where: { $0.annualRatePercent < 0 }) {
            throw LoanTermsError.negativeInterestRate
        }
    }
}
