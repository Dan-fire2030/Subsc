import XCTest
@testable import Subsc

final class BubbleLayoutTests: XCTestCase {
    private enum TestLayout {
        static let size = CGSize(width: 320, height: 180)
        static let geometryTolerance: CGFloat = 0.001
        static let ratioTolerance = 0.001
    }

    func testCircleAreasAreProportionalToAmounts() throws {
        let entries = [
            entry(id: "small", amount: 1_000),
            entry(id: "medium", amount: 4_000),
            entry(id: "large", amount: 9_000)
        ]

        let nodes = BubbleLayout.layout(entries: entries, in: TestLayout.size)
        let small = try node(id: "small", in: nodes)
        let medium = try node(id: "medium", in: nodes)
        let large = try node(id: "large", in: nodes)

        XCTAssertEqual(
            Double(medium.radius * medium.radius / (small.radius * small.radius)),
            4,
            accuracy: TestLayout.ratioTolerance
        )
        XCTAssertEqual(
            Double(large.radius * large.radius / (small.radius * small.radius)),
            9,
            accuracy: TestLayout.ratioTolerance
        )
    }

    /// クラスタが円形に固まると、横長の領域では左右に大きな余白が残ります。
    /// 縦横どちらもおおむね埋まっていることを縛ります。
    func testLayoutFillsBothAxesOfAWideRectangle() throws {
        let entries = (0..<9).map { entry(id: "item-\($0)", amount: Double(9 - $0) * 500) }
        let nodes = BubbleLayout.layout(entries: entries, in: TestLayout.size)

        let minimumX = try XCTUnwrap(nodes.map { $0.center.x - $0.radius }.min())
        let maximumX = try XCTUnwrap(nodes.map { $0.center.x + $0.radius }.max())
        let minimumY = try XCTUnwrap(nodes.map { $0.center.y - $0.radius }.min())
        let maximumY = try XCTUnwrap(nodes.map { $0.center.y + $0.radius }.max())

        XCTAssertGreaterThanOrEqual(
            (maximumX - minimumX) / TestLayout.size.width,
            0.8,
            "横方向が埋まっていません"
        )
        XCTAssertGreaterThanOrEqual(
            (maximumY - minimumY) / TestLayout.size.height,
            0.8,
            "縦方向が埋まっていません"
        )
    }

    func testCirclesDoNotOverlap() {
        assertValidGeometry(for: variedEntries())
    }

    func testEveryCircleFitsInsideTheRectangle() {
        let nodes = BubbleLayout.layout(entries: variedEntries(), in: TestLayout.size)

        for node in nodes {
            XCTAssertGreaterThanOrEqual(node.center.x - node.radius, -TestLayout.geometryTolerance)
            XCTAssertGreaterThanOrEqual(node.center.y - node.radius, -TestLayout.geometryTolerance)
            XCTAssertLessThanOrEqual(
                node.center.x + node.radius,
                TestLayout.size.width + TestLayout.geometryTolerance
            )
            XCTAssertLessThanOrEqual(
                node.center.y + node.radius,
                TestLayout.size.height + TestLayout.geometryTolerance
            )
        }
    }

    func testSameInputProducesSameLayout() {
        let entries = variedEntries()

        XCTAssertEqual(
            BubbleLayout.layout(entries: entries, in: TestLayout.size),
            BubbleLayout.layout(entries: entries, in: TestLayout.size)
        )
    }

    func testNoEntriesReturnsEmptyLayout() {
        XCTAssertTrue(BubbleLayout.layout(entries: [], in: TestLayout.size).isEmpty)
    }

    func testOneEntryIsCenteredAndFits() throws {
        let nodes = BubbleLayout.layout(
            entries: [entry(id: "single", amount: 1_000)],
            in: TestLayout.size
        )

        let node = try XCTUnwrap(nodes.first)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(node.center.x, TestLayout.size.width / 2, accuracy: TestLayout.geometryTolerance)
        XCTAssertEqual(node.center.y, TestLayout.size.height / 2, accuracy: TestLayout.geometryTolerance)
        XCTAssertGreaterThan(node.radius, 0)
        XCTAssertLessThanOrEqual(node.radius, TestLayout.size.height / 2)
    }

    func testTenEqualAmountsProduceValidGeometry() {
        let entries = (0..<10).map { entry(id: "equal-\($0)", amount: 1_000) }

        assertValidGeometry(for: entries)
    }

    func testOneExtremeAmountAndNineSmallAmountsProduceValidGeometry() {
        let entries = [entry(id: "extreme", amount: 1_000_000)]
            + (0..<9).map { entry(id: "small-\($0)", amount: 100) }

        assertValidGeometry(for: entries)
    }

    private func assertValidGeometry(
        for entries: [ReportChartItem],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let nodes = BubbleLayout.layout(entries: entries, in: TestLayout.size)

        XCTAssertEqual(nodes.count, entries.count, file: file, line: line)
        for (index, first) in nodes.enumerated() {
            XCTAssertGreaterThan(first.radius, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(
                first.center.x - first.radius,
                -TestLayout.geometryTolerance,
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                first.center.y - first.radius,
                -TestLayout.geometryTolerance,
                file: file,
                line: line
            )
            XCTAssertLessThanOrEqual(
                first.center.x + first.radius,
                TestLayout.size.width + TestLayout.geometryTolerance,
                file: file,
                line: line
            )
            XCTAssertLessThanOrEqual(
                first.center.y + first.radius,
                TestLayout.size.height + TestLayout.geometryTolerance,
                file: file,
                line: line
            )

            for second in nodes.dropFirst(index + 1) {
                let distance = hypot(
                    first.center.x - second.center.x,
                    first.center.y - second.center.y
                )
                XCTAssertGreaterThanOrEqual(
                    distance + TestLayout.geometryTolerance,
                    first.radius + second.radius,
                    "\(first.id) と \(second.id) が重なっています",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func node(id: String, in nodes: [BubbleNode]) throws -> BubbleNode {
        try XCTUnwrap(nodes.first { $0.id == id })
    }

    private func variedEntries() -> [ReportChartItem] {
        [
            entry(id: "a", amount: 10_000),
            entry(id: "b", amount: 8_000),
            entry(id: "c", amount: 5_000),
            entry(id: "d", amount: 3_000),
            entry(id: "e", amount: 1_000),
            entry(id: "f", amount: 500)
        ]
    }

    private func entry(id: String, amount: Double) -> ReportChartItem {
        ReportChartItem(
            id: id,
            name: id,
            amount: amount,
            colorHex: "#64D2FF",
            isEstimated: false,
            opacity: 1
        )
    }
}
