import XCTest
@testable import Subsc

/// 月次実績の記録が、同じ年月を1件に保てているかのテストです。
///
/// CloudKitミラーリングでは `@Attribute(.unique)` が使えないため、
/// 一意性はアプリ側で保つしかありません。ここが崩れると同じ月が二重計上されます。
final class AmountEntryStoreTests: XCTestCase {
    private func makeUtility() -> Subscription {
        Subscription(
            name: "電気代",
            costType: .utility,
            hasVariableAmount: true,
            originalAmount: 0,
            renewalDate: .now
        )
    }

    func testRecordingANewMonthAddsAnEntry() {
        let electricity = makeUtility()

        AmountEntryStore.record(amount: 8200, year: 2026, month: 7, on: electricity)

        XCTAssertEqual(electricity.sortedAmountEntries.count, 1)
        XCTAssertEqual(electricity.sortedAmountEntries.first?.amount, 8200)
        XCTAssertEqual(electricity.sortedAmountEntries.first?.periodKey, 202607)
    }

    func testRecordingTheSameMonthTwiceOverwritesInsteadOfDuplicating() {
        let electricity = makeUtility()

        AmountEntryStore.record(amount: 8200, year: 2026, month: 7, on: electricity)
        AmountEntryStore.record(amount: 7900, year: 2026, month: 7, on: electricity)

        XCTAssertEqual(electricity.sortedAmountEntries.count, 1)
        XCTAssertEqual(electricity.sortedAmountEntries.first?.amount, 7900)
    }

    func testDifferentMonthsAreKeptSeparately() {
        let electricity = makeUtility()

        AmountEntryStore.record(amount: 6500, year: 2026, month: 6, on: electricity)
        AmountEntryStore.record(amount: 8200, year: 2026, month: 7, on: electricity)

        XCTAssertEqual(electricity.sortedAmountEntries.map(\.periodKey), [202607, 202606])
    }

    func testRecordingMarksTheSubscriptionAsUpdated() {
        let electricity = makeUtility()
        let recordedAt = Date(timeIntervalSince1970: 1_800_000_000)

        AmountEntryStore.record(
            amount: 8200,
            year: 2026,
            month: 7,
            on: electricity,
            recordedAt: recordedAt
        )

        XCTAssertEqual(electricity.updatedAt, recordedAt)
        XCTAssertEqual(electricity.sortedAmountEntries.first?.recordedAt, recordedAt)
    }

    func testLookingUpAMonthFindsOnlyThatMonth() {
        let electricity = makeUtility()
        AmountEntryStore.record(amount: 6500, year: 2026, month: 6, on: electricity)

        XCTAssertEqual(AmountEntryStore.entry(on: electricity, periodKey: 202606)?.amount, 6500)
        XCTAssertNil(AmountEntryStore.entry(on: electricity, periodKey: 202607))
    }

    func testHasRecordAnswersWhetherTheMonthIsFilledIn() {
        let electricity = makeUtility()
        AmountEntryStore.record(amount: 6500, year: 2026, month: 6, on: electricity)

        XCTAssertTrue(AmountEntryStore.hasRecord(on: electricity, periodKey: 202606))
        XCTAssertFalse(AmountEntryStore.hasRecord(on: electricity, periodKey: 202607))
    }

    func testRecordingIntoAFixedCostStillWorksSoSwitchingModesDoesNotLoseData() {
        // 変動費から定額へ戻したあとも、過去の実績は残したままにする
        let netflix = Subscription(name: "Netflix", originalAmount: 1490, renewalDate: .now)

        AmountEntryStore.record(amount: 1490, year: 2026, month: 7, on: netflix)

        XCTAssertEqual(netflix.sortedAmountEntries.count, 1)
        // 定額として計算されるので、実績があっても金額は originalAmount のまま
        XCTAssertEqual(netflix.monthlyAmount(forPeriodKey: 202607).amount, 1490)
    }
}
