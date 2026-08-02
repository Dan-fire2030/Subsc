import XCTest
@testable import Subsc

/// 借入フォームの入力検証のテストです。
///
/// **保存してから「返済が終わりません」と言われても直しようがない**ため、
/// 予定表を作れるかどうかを保存前に確かめます。理由は日本語でそのまま画面に出します。
final class LoanFormInputTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }
    }

    // MARK: - 通る入力

    func testValidInputPasses() throws {
        XCTAssertNoThrow(try makeInput().validate(calendar: Fixture.calendar))
    }

    func testRevolvingWithReducingTiersPasses() {
        var input = makeInput()
        input.method = .revolving
        input.totalInstallments = 0
        input.slidingTiers = [
            RevolvingTier(upperBalance: 500_000, monthlyPayment: 15_000),
            RevolvingTier(upperBalance: 1_500_000, monthlyPayment: 30_000)
        ]

        XCTAssertNoThrow(try input.validate(calendar: Fixture.calendar))
    }

    // MARK: - フォーム固有の検証

    func testEmptyNameIsRejected() {
        var input = makeInput()
        input.name = "   "

        assertThrows(input, LoanFormError.nameRequired)
    }

    func testPaymentDayOutOfRangeIsRejected() {
        var input = makeInput()
        input.paymentDay = 32

        assertThrows(input, LoanFormError.paymentDayOutOfRange)
    }

    func testNegativeBonusAmountIsRejected() {
        var input = makeInput()
        input.bonusAmount = -10_000

        assertThrows(input, LoanFormError.negativeBonusAmount)
    }

    // MARK: - 計算側の検証がそのまま伝わること

    func testZeroInstallmentCountIsRejected() {
        var input = makeInput()
        input.totalInstallments = 0

        assertThrows(input, LoanTermsError.installmentCountMustBePositive)
    }

    func testZeroPrincipalIsRejected() {
        var input = makeInput()
        input.originalPrincipal = 0

        assertThrows(input, LoanTermsError.principalMustBePositive)
    }

    func testNegativeRateIsRejected() {
        var input = makeInput()
        input.annualRatePercent = -1

        assertThrows(input, LoanTermsError.negativeInterestRate)
    }

    func testRevolvingWithoutTiersIsRejected() {
        var input = makeInput()
        input.method = .revolving
        input.totalInstallments = 0
        input.slidingTiers = []

        assertThrows(input, LoanTermsError.revolvingTiersMissing)
    }

    /// **利息が定額を食い尽くす帯は弾きます。** 通すと残高が永久に減りません。
    func testRevolvingTierThatNeverReducesPrincipalIsRejected() {
        var input = makeInput()
        input.method = .revolving
        input.totalInstallments = 0
        input.annualRatePercent = 18
        input.originalPrincipal = 1_000_000
        input.slidingTiers = [RevolvingTier(upperBalance: 1_000_000, monthlyPayment: 5_000)]

        XCTAssertThrowsError(try input.validate(calendar: Fixture.calendar)) { error in
            guard case LoanTermsError.revolvingPaymentDoesNotReducePrincipal = error else {
                return XCTFail("元金が減らない帯として弾かれていません：\(error)")
            }
        }
    }

    func testBonusMonthOutOfRangeIsRejected() {
        var input = makeInput()
        input.bonusMonths = [13]
        input.bonusAmount = 100_000

        assertThrows(input, LoanTermsError.bonusMonthOutOfRange(13))
    }

    // MARK: - 契約への書き戻し

    func testApplyWritesEveryFieldToTheLoan() {
        var input = makeInput()
        input.name = "  住宅ローン  "
        input.note = " A銀行 "
        input.bonusMonths = [12, 6]
        input.bonusAmount = 200_000
        input.interestType = .variable
        input.rateHistory = [
            LoanRateChange(effectiveFrom: date(2026, 4, 1), annualRatePercent: 1.2)
        ]
        let loan = Loan(name: "仮")

        input.apply(to: loan)

        XCTAssertEqual(loan.name, "住宅ローン", "前後の空白は落とします。")
        XCTAssertEqual(loan.note, "A銀行")
        XCTAssertEqual(loan.method, .equalPayment)
        XCTAssertEqual(loan.origin, .fromOrigin)
        XCTAssertEqual(loan.originalPrincipal, 1_000_000)
        XCTAssertEqual(loan.totalInstallments, 12)
        XCTAssertEqual(loan.paymentDay, 27)
        XCTAssertEqual(loan.bonusMonths, [6, 12], "月は昇順に整えて保存します。")
        XCTAssertEqual(loan.bonusAmount, 200_000)
        XCTAssertEqual(loan.rateHistory.count, 1)
        XCTAssertEqual(loan.borrowedOn, date(2025, 12, 10))
    }

    /// 「今の残高から」登録したときは、当初元本側の日付を持ち込みません。
    func testApplyKeepsOnlyTheDateThatTheRegistrationStyleUses() {
        var input = makeInput()
        input.origin = .fromCurrentBalance
        input.startingBalance = 400_000
        input.startingInstallments = 6
        let loan = Loan(name: "仮")

        input.apply(to: loan)

        XCTAssertEqual(loan.origin, .fromCurrentBalance)
        XCTAssertEqual(loan.startingBalance, 400_000)
        XCTAssertEqual(loan.startingInstallments, 6)
        XCTAssertNil(loan.borrowedOn)
        XCTAssertNotNil(loan.startedTrackingOn)
    }

    /// 固定金利では、変動金利用に入れた利率履歴を持ち込みません。混ざると計算が食い違います。
    func testFixedInterestDropsTheRateHistory() {
        var input = makeInput()
        input.interestType = .fixed
        input.rateHistory = [
            LoanRateChange(effectiveFrom: date(2026, 4, 1), annualRatePercent: 1.2)
        ]
        let loan = Loan(name: "仮")

        input.apply(to: loan)

        XCTAssertTrue(loan.rateHistory.isEmpty)
    }

    /// リボ払い以外では帯を持ち込みません。
    func testNonRevolvingDropsTheSlidingTiers() {
        var input = makeInput()
        input.slidingTiers = [RevolvingTier(upperBalance: 500_000, monthlyPayment: 15_000)]
        let loan = Loan(name: "仮")

        input.apply(to: loan)

        XCTAssertTrue(loan.slidingTiers.isEmpty)
    }

    // MARK: - 補助

    private func makeInput() -> LoanFormInput {
        LoanFormInput(
            name: "自動車ローン",
            note: "",
            method: .equalPayment,
            interestType: .fixed,
            origin: .fromOrigin,
            annualRatePercent: 3.0,
            rateHistory: [],
            slidingTiers: [],
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            startingBalance: 0,
            startingInstallments: 0,
            startedTrackingOn: date(2026, 1, 1),
            paymentDay: 27,
            bonusMonths: [],
            bonusAmount: 0
        )
    }

    private func assertThrows<E: Error & Equatable>(
        _ input: LoanFormInput,
        _ expected: E,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try input.validate(calendar: Fixture.calendar),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? E,
                expected,
                "想定と違う理由で弾かれました：\(error)",
                file: file,
                line: line
            )
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Fixture.calendar.date(from: components) ?? .distantPast
    }
}
