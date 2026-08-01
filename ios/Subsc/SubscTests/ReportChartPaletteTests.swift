import XCTest
@testable import Subsc

final class ReportChartPaletteTests: XCTestCase {
    func testAllFilterAggregatesByCostTypeAndUsesCostTypeColor() {
        let items = ReportChartPalette.items(
            from: [
                entry(id: "a", amount: 300, colorHex: "#111111", costType: .utility),
                entry(id: "b", amount: 100, colorHex: "#222222", costType: .subscription),
                entry(id: "c", amount: 200, colorHex: "#333333", costType: .utility, isEstimated: true)
            ],
            filter: .all
        )

        XCTAssertEqual(items.map(\.name), [CostType.utility.title, CostType.subscription.title])
        XCTAssertEqual(items.map(\.amount), [500, 100])
        XCTAssertEqual(items.map(\.colorHex), [CostType.utility.colorHex, CostType.subscription.colorHex])
        XCTAssertTrue(items[0].isEstimated)
        XCTAssertEqual(items[0].opacity, ReportChartPalette.estimatedOpacity)
    }

    func testNarrowedFilterKeepsEntriesAndUsesUserColorsInDescendingOrder() {
        let items = ReportChartPalette.items(
            from: [
                entry(id: "b", amount: 100, colorHex: "#222222", costType: .utility),
                entry(id: "a", amount: 300, colorHex: "#111111", costType: .utility)
            ],
            filter: .only(.utility)
        )

        XCTAssertEqual(items.map(\.id), ["a", "b"])
        XCTAssertEqual(items.map(\.colorHex), ["#111111", "#222222"])
        XCTAssertEqual(items.map(\.opacity), [1, 1])
    }

    func testEqualAmountsUseStableIdentifierOrder() {
        let items = ReportChartPalette.items(
            from: [
                entry(id: "z", amount: 100, colorHex: "#111111", costType: .utility),
                entry(id: "a", amount: 100, colorHex: "#222222", costType: .utility)
            ],
            filter: .only(.utility)
        )

        XCTAssertEqual(items.map(\.id), ["a", "z"])
    }

    func testLengthsKeepTinyItemVisibleAndFillAvailableLength() {
        let items = ReportChartPalette.items(
            from: [
                entry(id: "large", amount: 999, colorHex: "#111111", costType: .utility),
                entry(id: "tiny", amount: 1, colorHex: "#222222", costType: .utility)
            ],
            filter: .only(.utility)
        )

        let lengths = ReportChartPalette.lengths(
            for: items,
            availableLength: 100,
            minimumLength: 6
        )

        XCTAssertEqual(lengths.count, 2)
        XCTAssertGreaterThanOrEqual(lengths[1], 6)
        XCTAssertEqual(lengths.reduce(0, +), 100, accuracy: 0.001)
    }

    func testLengthsShareNarrowSpaceWithoutOverflowing() {
        let items = (0..<3).map { index in
            ReportChartItem(
                id: "\(index)",
                name: "費目\(index)",
                amount: 100,
                colorHex: "#111111",
                isEstimated: false,
                opacity: 1
            )
        }

        let lengths = ReportChartPalette.lengths(
            for: items,
            availableLength: 12,
            minimumLength: 6
        )

        XCTAssertEqual(lengths, [4, 4, 4])
    }

    private func entry(
        id: String,
        amount: Double,
        colorHex: String,
        costType: CostType,
        isEstimated: Bool = false
    ) -> ReportEntry {
        ReportEntry(
            id: id,
            name: id,
            amount: amount,
            colorHex: colorHex,
            costType: costType,
            isEstimated: isEstimated
        )
    }
}
