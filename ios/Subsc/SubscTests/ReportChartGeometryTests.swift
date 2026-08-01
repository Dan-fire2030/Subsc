import XCTest
@testable import Subsc

final class ReportChartGeometryTests: XCTestCase {
    func testBubbleScaleIsClampedToSupportedRange() {
        XCTAssertEqual(BubbleChartTransform.clampedScale(0.5), 1)
        XCTAssertEqual(BubbleChartTransform.clampedScale(2.5), 2.5)
        XCTAssertEqual(BubbleChartTransform.clampedScale(8), 4)
    }

    /// 等倍に戻った円が画面外へ残らないよう、パン位置も必ず中央へ戻します。
    func testBubbleOffsetReturnsToZeroAtMinimumScale() {
        let offset = BubbleChartTransform.clampedOffset(
            CGSize(width: 80, height: -40),
            in: CGSize(width: 320, height: 132),
            scale: 1
        )

        XCTAssertEqual(offset, .zero)
    }

    func testBubbleOffsetStaysWithinZoomedContentBounds() {
        let offset = BubbleChartTransform.clampedOffset(
            CGSize(width: 1_000, height: -1_000),
            in: CGSize(width: 320, height: 132),
            scale: 2
        )

        XCTAssertEqual(offset.width, 160)
        XCTAssertEqual(offset.height, -66)
    }

    func testColumnContentWidthIncludesBarsSpacingAndInsets() {
        XCTAssertEqual(
            ColumnChartGeometry.contentWidth(
                itemCount: 3,
                barWidth: 56,
                spacing: 12,
                horizontalPadding: 10
            ),
            212
        )
    }

    func testColumnContentWidthIsZeroWithoutItems() {
        XCTAssertEqual(
            ColumnChartGeometry.contentWidth(
                itemCount: 0,
                barWidth: 56,
                spacing: 12,
                horizontalPadding: 10
            ),
            0
        )
    }

    func testLargestColumnUsesAllAvailableHeight() {
        XCTAssertEqual(
            ColumnChartGeometry.barHeight(
                amount: 1_000,
                maximumAmount: 1_000,
                availableHeight: 100,
                minimumHeight: 8
            ),
            100
        )
    }

    func testColumnHeightKeepsSmallValuesVisibleWithoutOverflowing() {
        let height = ColumnChartGeometry.barHeight(
            amount: 1,
            maximumAmount: 1_000_000,
            availableHeight: 100,
            minimumHeight: 8
        )

        XCTAssertGreaterThanOrEqual(height, 8)
        XCTAssertLessThanOrEqual(height, 100)
    }
}
