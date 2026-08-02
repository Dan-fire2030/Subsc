import XCTest
@testable import Subsc

/// 試算3種のテストです。
///
/// **「早まる」「減る」を数字で示す機能**なので、向きが逆でも画面上はそれらしく見えます。
/// 差分の符号と大きさをここで縛ります。
final class LoanSimulatorTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 繰上返済

    func testPrepaymentShortensTheScheduleAndSavesInterest() throws {
        let outcome = try LoanSimulator.prepayment(
            of: 300_000,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertGreaterThan(outcome.monthsShortened, 0)
        XCTAssertGreaterThan(outcome.interestSaved, 0)
        XCTAssertLessThan(
            outcome.simulated.totalInterest,
            outcome.baseline.totalInterest
        )
    }

    /// 上乗せが多いほど効果も大きくなります。逆転していたら計算の向きが誤っています。
    func testLargerPrepaymentSavesMore() throws {
        let small = try LoanSimulator.prepayment(
            of: 100_000,
            on: makeTerms(),
            calendar: Fixture.calendar
        )
        let large = try LoanSimulator.prepayment(
            of: 500_000,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertGreaterThan(large.interestSaved, small.interestSaved)
        XCTAssertGreaterThanOrEqual(large.monthsShortened, small.monthsShortened)
    }

    /// 0円を入れても何も変わりません。差分が出るなら基準側の作り方が誤っています。
    func testZeroPrepaymentChangesNothing() throws {
        let outcome = try LoanSimulator.prepayment(
            of: 0,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertEqual(outcome.monthsShortened, 0)
        XCTAssertEqual(outcome.interestSaved, 0, accuracy: 0.5)
    }

    // MARK: - 利率の変更

    func testRaisingTheRateIncreasesInterestAndMonthlyPayment() throws {
        let outcome = try LoanSimulator.rateChange(
            to: 5.0,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertLessThan(outcome.interestSaved, 0, "利息が増えるので、減る額はマイナスです。")
        XCTAssertGreaterThan(outcome.simulatedMonthlyPayment, outcome.baselineMonthlyPayment)
    }

    func testLoweringTheRateReducesInterestAndMonthlyPayment() throws {
        let outcome = try LoanSimulator.rateChange(
            to: 1.0,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertGreaterThan(outcome.interestSaved, 0)
        XCTAssertLessThan(outcome.simulatedMonthlyPayment, outcome.baselineMonthlyPayment)
    }

    /// **利率の見直し履歴を持ち込まないこと。** 残っていると、試算した利率より履歴が優先されます。
    func testRateChangeIgnoresTheExistingRateHistory() throws {
        var terms = makeTerms()
        terms.interestType = .variable
        terms.rateChanges = [
            LoanRateChange(effectiveFrom: date(2020, 1, 1), annualRatePercent: 15)
        ]

        let outcome = try LoanSimulator.rateChange(
            to: 1.0,
            on: terms,
            calendar: Fixture.calendar
        )
        let plain = try LoanSimulator.rateChange(
            to: 1.0,
            on: makeTerms(),
            calendar: Fixture.calendar
        )

        XCTAssertEqual(
            outcome.simulated.totalInterest,
            plain.simulated.totalInterest,
            accuracy: 0.5
        )
    }

    // MARK: - 借入シミュレーター

    /// 電卓で検算した既知の値と一致すること。100万円・年利3.0％・12回で毎月84,694円です。
    func testEstimateMatchesTheKnownAnnuityPayment() throws {
        let schedule = try LoanSimulator.estimate(makeTerms(), calendar: Fixture.calendar)
        let first = try XCTUnwrap(schedule.installments.first)

        XCTAssertEqual(first.amount, 84_694, accuracy: 0.5)
        XCTAssertEqual(schedule.paymentCount, 12)
        XCTAssertEqual(schedule.completionDate, date(2026, 12, 27))
    }

    func testEstimateRejectsAnImpossibleSetting() {
        var terms = makeTerms()
        terms.principal = 0

        XCTAssertThrowsError(try LoanSimulator.estimate(terms, calendar: Fixture.calendar)) { error in
            XCTAssertEqual(error as? LoanTermsError, .principalMustBePositive)
        }
    }

    // MARK: - 今の残高からの試算

    /// **当初の条件ではなく、今の残高と残り回数から試算すること。**
    /// 返し終えた回まで巻き込むと「早まる月数」が過大になります。
    func testRemainingTermsUseTheCurrentBalanceAndCount() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        for period in 1...4 {
            let payment = try XCTUnwrap(
                LoanPaymentStore.sortedPayments(on: loan).first { $0.period == period }
            )
            try LoanPaymentStore.recordPayment(
                amount: payment.scheduledAmount,
                period: period,
                on: loan,
                calendar: Fixture.calendar
            )
        }
        let summary = LoanSummary.make(for: loan)

        let terms = try XCTUnwrap(LoanSimulator.remainingTerms(for: loan, summary: summary))

        XCTAssertEqual(terms.principal, summary.currentBalance, accuracy: 0.5)
        XCTAssertEqual(terms.installmentCount, 8)
        XCTAssertEqual(terms.firstDueDate, date(2026, 5, 27))
    }

    /// 完済済みは試算できません。残高も残り回数も無いためです。
    func testRemainingTermsAreUnavailableWhenCompleted() throws {
        let loan = makeLoan()
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        for payment in LoanPaymentStore.sortedPayments(on: loan) {
            payment.status = .paid
        }
        let summary = LoanSummary.make(for: loan)

        XCTAssertNil(LoanSimulator.remainingTerms(for: loan, summary: summary))
    }

    // MARK: - 課金の線引き

    /// 1.0.0 では全機能を無料で出します（SPEC 8節）。判定を1箇所へ集約していることの確認です。
    func testSimulationsAreFreeInTheFirstRelease() {
        XCTAssertTrue(LoanSimulationAccess.isUnlocked)
    }

    // MARK: - 補助

    private func makeTerms() -> LoanTerms {
        LoanTerms(
            principal: 1_000_000,
            annualRatePercent: 3.0,
            installmentCount: 12,
            method: .equalPayment,
            firstDueDate: date(2026, 1, 27)
        )
    }

    private func makeLoan() -> Loan {
        Loan(
            name: "自動車ローン",
            method: .equalPayment,
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
