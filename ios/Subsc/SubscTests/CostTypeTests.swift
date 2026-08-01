import XCTest
@testable import Subsc

/// 種別・支払い方法・月次実績の、保存に関わる約束を固定するテストです。
///
/// これらの rawValue は CloudKit に保存されるため、**後から変えると既存データが読めなくなります**。
/// うっかりケース名を変えたときにここで落ちるようにしています。
final class CostTypeTests: XCTestCase {
    func testRawValuesAreStableBecauseTheyArePersisted() {
        XCTAssertEqual(CostType.subscription.rawValue, "subscription")
        XCTAssertEqual(CostType.communication.rawValue, "communication")
        XCTAssertEqual(CostType.utility.rawValue, "utility")
        XCTAssertEqual(CostType.fixed.rawValue, "fixed")
        XCTAssertEqual(CostType.allCases.count, 4)
    }

    func testTitlesAreShownInJapanese() {
        XCTAssertEqual(CostType.subscription.title, "サブスク")
        XCTAssertEqual(CostType.communication.title, "通信費")
        XCTAssertEqual(CostType.utility.title, "光熱費")
        XCTAssertEqual(CostType.fixed.title, "その他固定費")
    }

    func testOnlyUtilitySuggestsVariableAmountByDefault() {
        XCTAssertTrue(CostType.utility.suggestsVariableAmount)
        XCTAssertFalse(CostType.subscription.suggestsVariableAmount)
        XCTAssertFalse(CostType.communication.suggestsVariableAmount)
        XCTAssertFalse(CostType.fixed.suggestsVariableAmount)
    }

    func testColorHexValuesArePresentAndUniqueForEveryCostType() {
        let colorHexValues = CostType.allCases.map(\.colorHex)

        XCTAssertEqual(colorHexValues.count, 4)
        XCTAssertEqual(Set(colorHexValues).count, 4)
        XCTAssertFalse(colorHexValues.contains(where: \.isEmpty))
    }

    func testColorHexValuesUseSixDigitRGBFormat() throws {
        let pattern = /^#[0-9A-F]{6}$/

        for colorHex in CostType.allCases.map(\.colorHex) {
            XCTAssertNotNil(colorHex.wholeMatch(of: pattern), "\(colorHex) は #RRGGBB 形式ではありません")
        }
    }

    func testPaymentMethodRawValuesAreStable() {
        XCTAssertEqual(PaymentMethod.unspecified.rawValue, "unspecified")
        XCTAssertEqual(PaymentMethod.creditCard.rawValue, "creditCard")
        XCTAssertEqual(PaymentMethod.bankTransfer.rawValue, "bankTransfer")
        XCTAssertEqual(PaymentMethod.convenienceStore.rawValue, "convenienceStore")
        XCTAssertEqual(PaymentMethod.other.rawValue, "other")
        XCTAssertEqual(PaymentMethod.allCases.count, 5)
    }
}

final class SubscriptionCostTypeTests: XCTestCase {
    func testNewSubscriptionDefaultsToSubscriptionTypeAndFixedAmount() {
        let subscription = Subscription(name: "テスト", originalAmount: 1000, renewalDate: .now)

        XCTAssertEqual(subscription.costType, .subscription)
        XCTAssertFalse(subscription.hasVariableAmount)
        XCTAssertEqual(subscription.paymentMethod, .unspecified)
        XCTAssertEqual(subscription.paymentMethodNote, "")
        XCTAssertNil(subscription.amountEntries)
    }

    func testUnknownRawValuesFallBackInsteadOfCrashing() {
        let subscription = Subscription(name: "テスト", originalAmount: 0, renewalDate: .now)
        subscription.costTypeRaw = "未知の種別"
        subscription.paymentMethodRaw = "未知の支払い方法"

        XCTAssertEqual(subscription.costType, .subscription)
        XCTAssertEqual(subscription.paymentMethod, .unspecified)
    }

    func testSettingTheTypedValueWritesThroughToTheStoredRawValue() {
        let subscription = Subscription(name: "電気", originalAmount: 0, renewalDate: .now)

        subscription.costType = .utility
        subscription.paymentMethod = .bankTransfer

        XCTAssertEqual(subscription.costTypeRaw, "utility")
        XCTAssertEqual(subscription.paymentMethodRaw, "bankTransfer")
    }
}

final class AmountEntryTests: XCTestCase {
    func testPeriodKeyPacksYearAndMonthIntoOneComparableNumber() {
        let entry = AmountEntry(year: 2026, month: 7, amount: 8200)

        XCTAssertEqual(entry.periodKey, 202607)
    }

    func testPeriodKeysSortChronologicallyAcrossYearBoundaries() {
        let december = AmountEntry(year: 2026, month: 12, amount: 1)
        let january = AmountEntry(year: 2027, month: 1, amount: 1)

        XCTAssertLessThan(december.periodKey, january.periodKey)
    }

    func testPeriodKeyForDateUsesTheGivenCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31)) ?? .now

        XCTAssertEqual(AmountEntry.periodKey(for: date, calendar: calendar), 202607)
    }

    func testSortedAmountEntriesPutsTheNewestPeriodFirst() {
        let subscription = Subscription(name: "電気", originalAmount: 0, renewalDate: .now)
        subscription.amountEntries = [
            AmountEntry(year: 2026, month: 5, amount: 7000),
            AmountEntry(year: 2026, month: 7, amount: 8200),
            AmountEntry(year: 2026, month: 6, amount: 6500)
        ]

        XCTAssertEqual(subscription.sortedAmountEntries.map(\.periodKey), [202607, 202606, 202605])
    }
}
