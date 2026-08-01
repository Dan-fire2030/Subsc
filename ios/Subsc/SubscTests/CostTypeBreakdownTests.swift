import XCTest
@testable import Subsc

final class CostTypeBreakdownTests: XCTestCase {
    func testSlicesSumAmountsByCostType() {
        let slices = CostTypeBreakdown.slices(from: [
            entry(id: "video", amount: 1_000, costType: .subscription),
            entry(id: "music", amount: 500, costType: .subscription),
            entry(id: "phone", amount: 3_000, costType: .communication)
        ])

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices.first { $0.costType == .subscription }?.amount, 1_500)
        XCTAssertEqual(slices.first { $0.costType == .communication }?.amount, 3_000)
    }

    func testSliceIsEstimatedWhenAnyEntryInCostTypeIsEstimated() {
        let slices = CostTypeBreakdown.slices(from: [
            entry(id: "recorded", amount: 1_000, costType: .utility),
            entry(id: "estimated", amount: 2_000, costType: .utility, isEstimated: true),
            entry(id: "fixed", amount: 3_000, costType: .fixed)
        ])

        XCTAssertEqual(slices.first { $0.costType == .utility }?.isEstimated, true)
        XCTAssertEqual(slices.first { $0.costType == .fixed }?.isEstimated, false)
    }

    func testSlicesExcludeCostTypesWhoseTotalIsZero() {
        let slices = CostTypeBreakdown.slices(from: [
            entry(id: "zero", amount: 0, costType: .subscription),
            entry(id: "positive", amount: 1_000, costType: .communication)
        ])

        XCTAssertEqual(slices.map(\.costType), [.communication])
    }

    func testSlicesSortByAmountThenUseCostTypeOrderForTies() {
        let slices = CostTypeBreakdown.slices(from: [
            entry(id: "fixed", amount: 2_000, costType: .fixed),
            entry(id: "utility", amount: 3_000, costType: .utility),
            entry(id: "communication", amount: 2_000, costType: .communication),
            entry(id: "subscription", amount: 3_000, costType: .subscription)
        ])

        XCTAssertEqual(slices.map(\.costType), [
            .subscription,
            .utility,
            .communication,
            .fixed
        ])
    }

    func testSlicesReturnsEmptyForNoEntries() {
        XCTAssertTrue(CostTypeBreakdown.slices(from: []).isEmpty)
    }

    func testSlicesReturnsOneSliceForOneEntry() throws {
        let slices = CostTypeBreakdown.slices(from: [
            entry(id: "single", amount: 1_200, costType: .fixed, isEstimated: true)
        ])

        let slice = try XCTUnwrap(slices.first)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slice.costType, .fixed)
        XCTAssertEqual(slice.amount, 1_200)
        XCTAssertTrue(slice.isEstimated)
    }

    private func entry(
        id: String,
        amount: Double,
        costType: CostType,
        isEstimated: Bool = false
    ) -> ReportEntry {
        ReportEntry(
            id: id,
            name: id,
            amount: amount,
            colorHex: "#64D2FF",
            costType: costType,
            isEstimated: isEstimated
        )
    }
}
