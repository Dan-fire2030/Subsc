import XCTest
@testable import Subsc

/// `Loan` と `LoanPayment` の、**保存に関わる約束**を固定するテストです。
///
/// rawValue と CSV の書式は CloudKit に保存されるため、後から変えると既存データが読めなくなります。
final class LoanModelTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            return calendar
        }
    }

    // MARK: - rawValue

    func testRepaymentMethodRawValuesAreStableBecauseTheyArePersisted() {
        XCTAssertEqual(RepaymentMethod.equalPayment.rawValue, "equalPayment")
        XCTAssertEqual(RepaymentMethod.interestFree.rawValue, "interestFree")
        XCTAssertEqual(RepaymentMethod.revolving.rawValue, "revolving")
        XCTAssertEqual(RepaymentMethod.allCases.count, 3)
    }

    func testInterestTypeRawValuesAreStable() {
        XCTAssertEqual(InterestType.fixed.rawValue, "fixed")
        XCTAssertEqual(InterestType.variable.rawValue, "variable")
        XCTAssertEqual(InterestType.allCases.count, 2)
    }

    func testLoanOriginRawValuesAreStable() {
        XCTAssertEqual(LoanOrigin.fromOrigin.rawValue, "fromOrigin")
        XCTAssertEqual(LoanOrigin.fromCurrentBalance.rawValue, "fromCurrentBalance")
        XCTAssertEqual(LoanOrigin.allCases.count, 2)
    }

    func testLoanPaymentStatusRawValuesAreStable() {
        XCTAssertEqual(LoanPaymentStatus.scheduled.rawValue, "scheduled")
        XCTAssertEqual(LoanPaymentStatus.paid.rawValue, "paid")
        XCTAssertEqual(LoanPaymentStatus.missed.rawValue, "missed")
        XCTAssertEqual(LoanPaymentStatus.prepaid.rawValue, "prepaid")
        XCTAssertEqual(LoanPaymentStatus.allCases.count, 4)
    }

    func testTitlesAreShownInJapanese() {
        XCTAssertEqual(RepaymentMethod.equalPayment.title, "元利均等")
        XCTAssertEqual(RepaymentMethod.interestFree.title, "無利息")
        XCTAssertEqual(RepaymentMethod.revolving.title, "リボ払い")
        XCTAssertEqual(LoanPaymentStatus.missed.title, "滞納")
    }

    // MARK: - 未知の値へのフォールバック

    /// **未知の rawValue でクラッシュしないこと。** 新しい版で増えた値を古い版が読む場合に起きます。
    func testUnknownRawValuesFallBackInsteadOfCrashing() {
        let loan = makeLoan()
        loan.repaymentMethodRaw = "somethingNew"
        loan.interestTypeRaw = "somethingNew"
        loan.originRaw = "somethingNew"

        XCTAssertEqual(loan.method, .equalPayment)
        XCTAssertEqual(loan.interestType, .fixed)
        XCTAssertEqual(loan.origin, .fromOrigin)

        let payment = LoanPayment(year: 2026, month: 1, period: 1)
        payment.statusRaw = "somethingNew"
        XCTAssertEqual(payment.status, .scheduled)
    }

    func testSettingTheTypedValueWritesThroughToTheStoredRawValue() {
        let loan = makeLoan()

        loan.method = .revolving
        loan.interestType = .variable
        loan.origin = .fromCurrentBalance

        XCTAssertEqual(loan.repaymentMethodRaw, "revolving")
        XCTAssertEqual(loan.interestTypeRaw, "variable")
        XCTAssertEqual(loan.originRaw, "fromCurrentBalance")
    }

    // MARK: - CSV

    func testRateHistoryRoundTripsThroughCSV() {
        let changes = [
            LoanRateChange(effectiveFrom: date(2026, 10, 1), annualRatePercent: 1.5),
            LoanRateChange(effectiveFrom: date(2026, 4, 1), annualRatePercent: 1.2)
        ]

        let loan = makeLoan()
        loan.rateHistory = changes

        // **並びは適用日の昇順に正規化されます。**
        XCTAssertEqual(loan.rateHistoryCSV, "2026-04-01:1.2,2026-10-01:1.5")
        XCTAssertEqual(loan.rateHistory, changes.sorted { $0.effectiveFrom < $1.effectiveFrom })
    }

    func testSlidingTiersRoundTripThroughCSV() {
        let tiers = [
            RevolvingTier(upperBalance: 500_000, monthlyPayment: 15_000),
            RevolvingTier(upperBalance: 300_000, monthlyPayment: 10_000)
        ]

        let loan = makeLoan()
        loan.slidingTiers = tiers

        XCTAssertEqual(loan.slidingTiersCSV, "300000.0:10000.0,500000.0:15000.0")
        XCTAssertEqual(loan.slidingTiers, tiers.sorted { $0.upperBalance < $1.upperBalance })
    }

    func testBonusMonthsRoundTripThroughCSV() {
        let loan = makeLoan()
        loan.bonusMonths = [12, 6]

        XCTAssertEqual(loan.bonusMonthsCSV, "6,12")
        XCTAssertEqual(loan.bonusMonths, [6, 12])
    }

    /// **壊れたCSVでクラッシュしない。** 手で編集されることは無くても、
    /// 古い版が書いた形式を読む可能性があります。
    func testMalformedCSVIsIgnoredInsteadOfCrashing() {
        let loan = makeLoan()

        loan.rateHistoryCSV = "こわれた,2026-04-01:1.2,:::"
        loan.slidingTiersCSV = "abc:def,300000:10000"
        loan.bonusMonthsCSV = "6,なし,12"

        XCTAssertEqual(loan.rateHistory.count, 1)
        XCTAssertEqual(loan.slidingTiers.count, 1)
        XCTAssertEqual(loan.bonusMonths, [6, 12])
    }

    func testEmptyCSVProducesEmptyArrays() {
        let loan = makeLoan()

        XCTAssertTrue(loan.rateHistory.isEmpty)
        XCTAssertTrue(loan.slidingTiers.isEmpty)
        XCTAssertTrue(loan.bonusMonths.isEmpty)
    }

    // MARK: - 計算への詰め替え

    func testTermsUseTheOriginalPrincipalWhenRegisteredFromOrigin() {
        let loan = makeLoan()
        loan.origin = .fromOrigin
        loan.originalPrincipal = 1_000_000
        loan.totalInstallments = 12
        loan.startingBalance = 500_000
        loan.startingInstallments = 6

        let terms = loan.terms(nextDueDate: date(2026, 1, 27))

        XCTAssertEqual(terms.principal, 1_000_000)
        XCTAssertEqual(terms.installmentCount, 12)
    }

    func testTermsUseTheCurrentBalanceWhenRegisteredFromIt() {
        let loan = makeLoan()
        loan.origin = .fromCurrentBalance
        loan.originalPrincipal = 1_000_000
        loan.totalInstallments = 12
        loan.startingBalance = 500_000
        loan.startingInstallments = 6

        let terms = loan.terms(nextDueDate: date(2026, 1, 27))

        XCTAssertEqual(terms.principal, 500_000)
        XCTAssertEqual(terms.installmentCount, 6)
    }

    // MARK: - レポートへ計上する金額

    func testMissedPaymentCountsAsZero() {
        let payment = LoanPayment(year: 2026, month: 3, period: 3, scheduledAmount: 84_694)
        payment.status = .missed

        XCTAssertEqual(payment.effectiveAmount, 0)
    }

    /// **実績の0円と「未入力」を区別します。** `actualAmount` が nil なら予定額を使います。
    func testActualAmountOverridesTheScheduledAmountEvenWhenZero() {
        let payment = LoanPayment(year: 2026, month: 3, period: 3, scheduledAmount: 84_694)
        XCTAssertEqual(payment.effectiveAmount, 84_694)

        payment.actualAmount = 0
        XCTAssertEqual(payment.effectiveAmount, 0)
    }

    func testPeriodKeyPacksYearAndMonth() {
        let payment = LoanPayment(year: 2026, month: 7, period: 7)

        XCTAssertEqual(payment.periodKey, 202_607)
    }

    // MARK: - 補助

    private func makeLoan() -> Loan {
        Loan(name: "テストローン")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
