import XCTest
@testable import Subsc

/// よく使うサービスの同梱カタログについてのテストです。
///
/// **料金は持ちません。** 値上げのたびに古い額を見せることになり、
/// 「アプリが言った額」と実際の請求が食い違うほうが害が大きいためです。
final class ServiceCatalogTests: XCTestCase {
    func testEveryEntryUsesAKnownCategory() {
        for service in ServiceCatalog.all {
            XCTAssertTrue(
                CategoryCatalog.presets.contains(service.category),
                "\(service.name) のカテゴリ「\(service.category)」がプリセットにありません"
            )
        }
    }

    func testEveryEntryHasAValidColor() {
        for service in ServiceCatalog.all {
            XCTAssertEqual(service.colorHex.count, 7, "\(service.name) の色が #RRGGBB 形式ではありません")
            XCTAssertTrue(service.colorHex.hasPrefix("#"), "\(service.name) の色に # がありません")
            XCTAssertEqual(
                ColorHex.canonical(service.colorHex),
                service.colorHex.uppercased(),
                "\(service.name) の色を読み取れません"
            )
        }
    }

    func testNamesAreUnique() {
        let names = ServiceCatalog.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "同じ名前のサービスが重複しています")
    }

    // MARK: - 検索

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(ServiceCatalog.search("").count, ServiceCatalog.all.count)
        XCTAssertEqual(ServiceCatalog.search("   ").count, ServiceCatalog.all.count)
    }

    func testSearchMatchesTheNameRegardlessOfCase() {
        let hits = ServiceCatalog.search("netflix")

        XCTAssertEqual(hits.first?.name, "Netflix")
    }

    /// 「ネトフリ」のような通称でも引けます。正式名称しか通らないと結局スクロールになります。
    func testSearchMatchesNicknames() {
        XCTAssertEqual(ServiceCatalog.search("ネトフリ").first?.name, "Netflix")
        XCTAssertEqual(ServiceCatalog.search("プライム").first?.name, "Amazonプライム")
    }

    func testSearchIgnoresSurroundingWhitespace() {
        XCTAssertEqual(ServiceCatalog.search("  Spotify  ").first?.name, "Spotify")
    }

    func testSearchReturnsNothingForAnUnknownName() {
        XCTAssertTrue(ServiceCatalog.search("存在しないサービス名").isEmpty)
    }

    // MARK: - 種別

    /// 通信キャリアは通信費として入ります。サブスク扱いだと集計の意味が変わります。
    func testMobileCarriersAreCategorisedAsCommunication() {
        let carrier = ServiceCatalog.all.first { $0.name == "楽天モバイル" }

        XCTAssertEqual(carrier?.costType, .communication)
    }

    func testStreamingServicesAreSubscriptions() {
        let netflix = ServiceCatalog.all.first { $0.name == "Netflix" }

        XCTAssertEqual(netflix?.costType, .subscription)
    }

    /// **借入・ローンはカタログに入れません。** 返済予定表が要るため、費目の追加では作れません。
    func testCatalogHasNoLoans() {
        XCTAssertFalse(ServiceCatalog.all.contains { $0.costType == .loan })
    }

    // MARK: - 並び

    func testEntriesAreGroupedByCategoryInThePresetOrder() {
        let categories = ServiceCatalog.grouped.map(\.category)
        let expected = CategoryCatalog.presets.filter { preset in
            ServiceCatalog.all.contains { $0.category == preset }
        }

        XCTAssertEqual(categories, expected)
    }

    func testGroupingKeepsEveryEntry() {
        let grouped = ServiceCatalog.grouped.flatMap(\.services)

        XCTAssertEqual(grouped.count, ServiceCatalog.all.count)
    }
}
