import XCTest
@testable import Subsc

/// 返済計算は目視で正しさが分かりません。**電卓で検算した値を固定で置き**、そこから縛ります。
final class LoanScheduleCalculatorTests: XCTestCase {
    private enum Fixture {
        /// 実行日に依存させないため、カレンダーもタイムゾーンも固定します。
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        static let amountTolerance = 0.5
        static let balanceTolerance = 0.5
    }

    private var calculator: LoanScheduleCalculator {
        LoanScheduleCalculator(calendar: Fixture.calendar)
    }

    // MARK: - 元利均等

    /// 100万円・年利3.0%・12回の毎月返済額は、`P * r / (1 - (1 + r)^-n)` で 84,693.69… 円。
    /// 円未満は四捨五入して 84,694 円になります。
    func testEqualPaymentMonthlyAmountMatchesTheKnownValue() throws {
        let payment = try calculator.monthlyPayment(for: standardTerms())

        XCTAssertEqual(payment, 84_694, accuracy: Fixture.amountTolerance)
    }

    /// **利率0%でゼロ除算しないこと。** `P * r / (1 - (1+r)^-n)` は r = 0 で 0/0 になります。
    func testEqualPaymentWithZeroRateDividesPrincipalEvenly() throws {
        var terms = standardTerms()
        terms.annualRatePercent = 0

        let payment = try calculator.monthlyPayment(for: terms)

        XCTAssertEqual(payment, 1_000_000.0 / 12.0, accuracy: Fixture.amountTolerance)
    }

    func testEqualPaymentScheduleEndsWithZeroBalance() throws {
        let schedule = try calculator.schedule(for: standardTerms())

        let last = try XCTUnwrap(schedule.installments.last)
        XCTAssertEqual(last.balanceAfter, 0, accuracy: Fixture.balanceTolerance)
        XCTAssertEqual(schedule.installments.count, 12)
    }

    /// 総利息は 16,324 円ほど。**端数は最終回の元金へ寄せる**ので、最終回だけ額が変わります。
    func testEqualPaymentTotalInterestMatchesTheKnownValue() throws {
        let schedule = try calculator.schedule(for: standardTerms())

        XCTAssertEqual(schedule.totalInterest, 16_324.33, accuracy: 1)
    }

    func testEachInstallmentSplitsIntoPrincipalAndInterest() throws {
        let schedule = try calculator.schedule(for: standardTerms())

        for installment in schedule.installments {
            XCTAssertEqual(
                installment.amount,
                installment.principal + installment.interest,
                accuracy: Fixture.amountTolerance,
                "\(installment.period)回目の内訳が支払額と一致しません"
            )
        }
    }

    func testBalanceNeverIncreasesWhilePaying() throws {
        let schedule = try calculator.schedule(for: standardTerms())

        var previous = 1_000_000.0
        for installment in schedule.installments {
            XCTAssertLessThan(installment.balanceAfter, previous)
            previous = installment.balanceAfter
        }
    }

    // MARK: - 無利息

    func testInterestFreeDividesPrincipalEvenly() throws {
        let schedule = try calculator.schedule(for: interestFreeTerms())

        XCTAssertEqual(schedule.installments.count, 10)
        XCTAssertEqual(schedule.totalInterest, 0, accuracy: Fixture.amountTolerance)
        let first = try XCTUnwrap(schedule.installments.first)
        XCTAssertEqual(first.amount, 50_000, accuracy: Fixture.amountTolerance)
    }

    func testInterestFreeEndsWithZeroBalance() throws {
        let schedule = try calculator.schedule(for: interestFreeTerms())

        let last = try XCTUnwrap(schedule.installments.last)
        XCTAssertEqual(last.balanceAfter, 0, accuracy: Fixture.balanceTolerance)
    }

    // MARK: - リボ払い

    func testRevolvingUsesTheTierForTheCurrentBalance() throws {
        let schedule = try calculator.schedule(for: revolvingTerms())

        let first = try XCTUnwrap(schedule.installments.first)
        // 残高30万円は「50万円以下＝2万円」の帯に入ります。
        XCTAssertEqual(first.amount, 20_000, accuracy: Fixture.amountTolerance)
    }

    func testRevolvingEventuallyRepaysInFull() throws {
        let schedule = try calculator.schedule(for: revolvingTerms())

        let last = try XCTUnwrap(schedule.installments.last)
        XCTAssertEqual(last.balanceAfter, 0, accuracy: Fixture.balanceTolerance)
    }

    /// **利息が定額を食い尽くす帯は不正。** 残高が永久に減らず、完済予定日が無限になります。
    func testRevolvingRejectsATierThatNeverReducesPrincipal() {
        var terms = revolvingTerms()
        terms.annualRatePercent = 18
        // 月利1.5%＝残高30万円なら利息4,500円。返済額3,000円では元金が減りません。
        terms.revolvingTiers = [RevolvingTier(upperBalance: 500_000, monthlyPayment: 3_000)]

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(
                error as? LoanTermsError,
                .revolvingPaymentDoesNotReducePrincipal(balance: 300_000)
            )
        }
    }

    func testRevolvingRequiresAtLeastOneTier() {
        var terms = revolvingTerms()
        terms.revolvingTiers = []

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(error as? LoanTermsError, .revolvingTiersMissing)
        }
    }

    // MARK: - ボーナス返済

    /// ボーナス月の上乗せは**全額を元金へ充当**するので、完済が早まり総利息が減ります。
    func testBonusPaymentsShortenTheScheduleAndReduceInterest() throws {
        let standard = try calculator.schedule(for: standardTerms())

        var terms = standardTerms()
        terms.bonusMonths = [6, 12]
        terms.bonusAmount = 100_000
        let withBonus = try calculator.schedule(for: terms)

        XCTAssertLessThan(withBonus.installments.count, standard.installments.count)
        XCTAssertLessThan(withBonus.totalInterest, standard.totalInterest)
    }

    func testBonusMonthOutOfRangeIsRejected() {
        var terms = standardTerms()
        terms.bonusMonths = [13]
        terms.bonusAmount = 100_000

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(error as? LoanTermsError, .bonusMonthOutOfRange(13))
        }
    }

    // MARK: - 変動金利

    /// 適用日以降だけ新しい率で計算します。**未来の利率は現在の率が続く前提**で、予測はしません。
    func testRateChangeAppliesFromItsEffectiveDateOnward() throws {
        var terms = standardTerms()
        terms.interestType = .variable
        terms.rateChanges = [
            LoanRateChange(effectiveFrom: date(2026, 7, 1), annualRatePercent: 5.0)
        ]

        let raised = try calculator.schedule(for: terms)
        let standard = try calculator.schedule(for: standardTerms())

        XCTAssertGreaterThan(raised.totalInterest, standard.totalInterest)
    }

    func testRateBeforeTheFirstChangeUsesTheCurrentRate() throws {
        var terms = standardTerms()
        terms.interestType = .variable
        terms.rateChanges = [
            LoanRateChange(effectiveFrom: date(2027, 1, 1), annualRatePercent: 9.0)
        ]

        let schedule = try calculator.schedule(for: terms)
        let first = try XCTUnwrap(schedule.installments.first)

        // 1回目は2026-01-27で、変更日より前なので年利3.0%＝月利0.25%のまま。
        XCTAssertEqual(first.interest, 1_000_000 * 0.0025, accuracy: Fixture.amountTolerance)
    }

    // MARK: - 滞納

    /// 滞納した月は支払額0。**残高は減らず、その月の利息は残高へ乗ります。**
    func testMissedPaymentPaysNothingAndLeavesTheBalanceUnreduced() throws {
        let schedule = try calculator.schedule(for: standardTerms(), missedPeriods: [3])

        let missed = try XCTUnwrap(schedule.installments.first { $0.period == 3 })
        let previous = try XCTUnwrap(schedule.installments.first { $0.period == 2 })

        XCTAssertTrue(missed.isMissed)
        XCTAssertEqual(missed.amount, 0, accuracy: Fixture.amountTolerance)
        XCTAssertEqual(missed.principal, 0, accuracy: Fixture.amountTolerance)
        XCTAssertGreaterThan(missed.balanceAfter, previous.balanceAfter)
    }

    func testMissedPaymentPushesTheCompletionDateBackAndIncreasesInterest() throws {
        let standard = try calculator.schedule(for: standardTerms())
        let missed = try calculator.schedule(for: standardTerms(), missedPeriods: [3])

        let standardCompletion = try XCTUnwrap(standard.completionDate)
        let missedCompletion = try XCTUnwrap(missed.completionDate)

        XCTAssertGreaterThan(missedCompletion, standardCompletion)
        XCTAssertGreaterThan(missed.totalInterest, standard.totalInterest)
    }

    /// 遅延損害金は計算しません（SPEC 2節）。契約ごとに率も起算日も違い、正確に出せないためです。
    func testMissedPaymentDoesNotAddPenaltyInterest() throws {
        let schedule = try calculator.schedule(for: standardTerms(), missedPeriods: [3])

        let missed = try XCTUnwrap(schedule.installments.first { $0.period == 3 })
        let previous = try XCTUnwrap(schedule.installments.first { $0.period == 2 })

        // 乗るのは通常の月利ぶんだけ。罰則率は掛けません。
        XCTAssertEqual(
            missed.interest,
            previous.balanceAfter * 0.0025,
            accuracy: Fixture.amountTolerance
        )
    }

    // MARK: - 繰上返済（期間短縮型）

    func testPrepaymentReducesTheInstallmentCountAndTotalInterest() throws {
        let standard = try calculator.schedule(for: standardTerms())
        let prepaid = try calculator.schedule(
            for: standardTerms(),
            prepayments: [3: 200_000]
        )

        XCTAssertLessThan(prepaid.installments.count, standard.installments.count)
        XCTAssertLessThan(prepaid.totalInterest, standard.totalInterest)
    }

    /// 期間短縮型なので、**毎月の返済額は変わりません**（最終回の端数調整を除く）。
    func testPrepaymentKeepsTheMonthlyAmountUnchanged() throws {
        let schedule = try calculator.schedule(
            for: standardTerms(),
            prepayments: [3: 200_000]
        )

        let fourth = try XCTUnwrap(schedule.installments.first { $0.period == 4 })

        XCTAssertEqual(fourth.amount, 84_694, accuracy: Fixture.amountTolerance)
    }

    // MARK: - 2つの登録方式

    /// 「当初元本から」の途中経過と、「現在の残高から」を突き合わせます。
    /// **同じ状態を表す入力なら、以降の予定表は一致しなければなりません。**
    func testStartingFromCurrentBalanceMatchesTheRemainderOfTheOriginalSchedule() throws {
        let original = try calculator.schedule(for: standardTerms())
        let elapsed = 4
        let remainder = Array(original.installments.dropFirst(elapsed))
        let balanceAfterElapsed = try XCTUnwrap(original.installments[elapsed - 1].balanceAfter)

        var fromBalance = standardTerms()
        fromBalance.principal = balanceAfterElapsed
        fromBalance.installmentCount = 12 - elapsed
        fromBalance.firstDueDate = date(2026, 5, 27)

        let restarted = try calculator.schedule(for: fromBalance)

        XCTAssertEqual(restarted.installments.count, remainder.count)
        for (restartedRow, originalRow) in zip(restarted.installments, remainder) {
            XCTAssertEqual(restartedRow.dueDate, originalRow.dueDate)
            XCTAssertEqual(
                restartedRow.amount,
                originalRow.amount,
                accuracy: 1,
                "\(originalRow.period)回目の返済額が一致しません"
            )
            XCTAssertEqual(
                restartedRow.balanceAfter,
                originalRow.balanceAfter,
                accuracy: 1,
                "\(originalRow.period)回目の残高が一致しません"
            )
        }
    }

    // MARK: - 入力検証

    func testPrincipalMustBePositive() {
        var terms = standardTerms()
        terms.principal = 0

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(error as? LoanTermsError, .principalMustBePositive)
        }
    }

    func testInstallmentCountMustBePositive() {
        var terms = standardTerms()
        terms.installmentCount = 0

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(error as? LoanTermsError, .installmentCountMustBePositive)
        }
    }

    func testNegativeInterestRateIsRejected() {
        var terms = standardTerms()
        terms.annualRatePercent = -1

        XCTAssertThrowsError(try calculator.schedule(for: terms)) { error in
            XCTAssertEqual(error as? LoanTermsError, .negativeInterestRate)
        }
    }

    /// エラーは利用者にそのまま見せます。**日本語であることを縛ります。**
    func testErrorsAreDescribedInJapanese() {
        for error in [
            LoanTermsError.principalMustBePositive,
            .installmentCountMustBePositive,
            .negativeInterestRate,
            .revolvingTiersMissing,
            .scheduleDoesNotTerminate
        ] {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "\(error) に説明がありません")
            XCTAssertTrue(
                description.contains(where: { $0.unicodeScalars.contains { $0.value > 0x3000 } }),
                "\(error) の説明が日本語ではありません：\(description)"
            )
        }
    }

    // MARK: - 実行日への非依存

    func testSameInputProducesSameSchedule() throws {
        let first = try calculator.schedule(for: standardTerms())
        let second = try calculator.schedule(for: standardTerms())

        XCTAssertEqual(first, second)
    }

    func testDueDatesAdvanceOneMonthAtATime() throws {
        let schedule = try calculator.schedule(for: standardTerms())

        XCTAssertEqual(schedule.installments[0].dueDate, date(2026, 1, 27))
        XCTAssertEqual(schedule.installments[1].dueDate, date(2026, 2, 27))
        XCTAssertEqual(schedule.installments[11].dueDate, date(2026, 12, 27))
    }

    // MARK: - 補助

    private func standardTerms() -> LoanTerms {
        LoanTerms(
            principal: 1_000_000,
            annualRatePercent: 3.0,
            installmentCount: 12,
            method: .equalPayment,
            firstDueDate: date(2026, 1, 27)
        )
    }

    private func interestFreeTerms() -> LoanTerms {
        LoanTerms(
            principal: 500_000,
            annualRatePercent: 0,
            installmentCount: 10,
            method: .interestFree,
            firstDueDate: date(2026, 1, 27)
        )
    }

    private func revolvingTerms() -> LoanTerms {
        LoanTerms(
            principal: 300_000,
            annualRatePercent: 15.0,
            installmentCount: 0,
            method: .revolving,
            firstDueDate: date(2026, 1, 27),
            revolvingTiers: [
                RevolvingTier(upperBalance: 500_000, monthlyPayment: 20_000),
                RevolvingTier(upperBalance: 1_000_000, monthlyPayment: 30_000)
            ]
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
