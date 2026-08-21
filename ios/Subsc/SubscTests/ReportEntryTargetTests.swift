import XCTest
@testable import Subsc

/// 費目別料金の行から、編集する対象を引き当てるテストです。
///
/// **行のIDだけで見分けます。** 種別（`CostType`）では見分けられません。
/// 費目にも「借入・ローン」の種別があり、借入（`Loan`）と同じ種別になりうるためです。
final class ReportEntryTargetTests: XCTestCase {
    private func makeSubscription(clientID: String, costType: CostType = .subscription) -> Subscription {
        Subscription(
            clientID: clientID,
            name: "Netflix",
            costType: costType,
            originalAmount: 1_490,
            renewalDate: .now
        )
    }

    private func makeLoan(clientID: String) -> Loan {
        Loan(clientID: clientID, name: "自動車ローン")
    }

    private func makeEntry(id: String, costType: CostType = .subscription) -> ReportEntry {
        ReportEntry(
            id: id,
            name: "テスト",
            amount: 1_000,
            colorHex: "#007AFF",
            costType: costType,
            isEstimated: false
        )
    }

    func testSubscriptionEntryResolvesToItsSubscription() throws {
        let subscription = makeSubscription(clientID: "sub-1")
        let entry = makeEntry(id: "sub-1")

        let target = ReportEntryTarget.resolve(
            entry: entry,
            subscriptions: [subscription],
            loans: []
        )

        guard case .subscription(let resolved) = target else {
            return XCTFail("費目として引き当てられていません。")
        }
        XCTAssertIdentical(resolved, subscription)
    }

    func testLoanEntryResolvesToItsLoan() throws {
        let loan = makeLoan(clientID: "loan-client-1")
        let entry = makeEntry(id: "\(ReportEntry.loanIDPrefix)loan-client-1", costType: .loan)

        let target = ReportEntryTarget.resolve(
            entry: entry,
            subscriptions: [],
            loans: [loan]
        )

        guard case .loan(let resolved) = target else {
            return XCTFail("借入として引き当てられていません。")
        }
        XCTAssertIdentical(resolved, loan)
    }

    /// 種別が「借入・ローン」の費目を、借入と取り違えてはいけません。
    func testSubscriptionWithLoanCostTypeIsStillASubscription() throws {
        let subscription = makeSubscription(clientID: "sub-2", costType: .loan)
        let loan = makeLoan(clientID: "sub-2")
        let entry = makeEntry(id: "sub-2", costType: .loan)

        let target = ReportEntryTarget.resolve(
            entry: entry,
            subscriptions: [subscription],
            loans: [loan]
        )

        guard case .subscription(let resolved) = target else {
            return XCTFail("接頭辞が無い行は費目として扱います。")
        }
        XCTAssertIdentical(resolved, subscription)
    }

    /// 費目と借入が同じ `clientID` でも取り違えません。
    func testSameClientIDOnBothSidesDoesNotCollide() throws {
        let subscription = makeSubscription(clientID: "same")
        let loan = makeLoan(clientID: "same")

        let loanTarget = ReportEntryTarget.resolve(
            entry: makeEntry(id: "\(ReportEntry.loanIDPrefix)same", costType: .loan),
            subscriptions: [subscription],
            loans: [loan]
        )
        guard case .loan(let resolvedLoan) = loanTarget else {
            return XCTFail("借入として引き当てられていません。")
        }
        XCTAssertIdentical(resolvedLoan, loan)
    }

    /// アーカイブや削除で対象が消えている行では、開く先がありません。
    func testMissingSubscriptionResolvesToNothing() {
        XCTAssertNil(
            ReportEntryTarget.resolve(
                entry: makeEntry(id: "gone"),
                subscriptions: [],
                loans: []
            )
        )
    }

    func testMissingLoanResolvesToNothing() {
        XCTAssertNil(
            ReportEntryTarget.resolve(
                entry: makeEntry(id: "\(ReportEntry.loanIDPrefix)gone", costType: .loan),
                subscriptions: [],
                loans: []
            )
        )
    }

    /// レポート側が組み立てるIDと、引き当て側が読む接頭辞は同じものを使います。
    func testReportBuildsLoanIDWithTheSharedPrefix() throws {
        let loan = makeLoan(clientID: "prefix-check")
        let entry = makeEntry(id: "\(ReportEntry.loanIDPrefix)prefix-check", costType: .loan)

        XCTAssertEqual(ReportEntry.loanIDPrefix, "loan-")
        XCTAssertEqual(entry.loanClientID, "prefix-check")
        XCTAssertNil(makeEntry(id: "prefix-check").loanClientID)
        XCTAssertEqual(loan.clientID, "prefix-check")
    }
}
