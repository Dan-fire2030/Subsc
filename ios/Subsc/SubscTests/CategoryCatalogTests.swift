import XCTest
@testable import Subsc

final class CategoryCatalogTests: XCTestCase {

    // MARK: - 選択肢の組み立て

    func testOptionsStartWithThePresetsInTheirFixedOrder() {
        let options = CategoryCatalog.options(usedCategories: [])
        XCTAssertEqual(options, CategoryCatalog.presets)
    }

    func testUsedCategoriesAreAppendedAfterThePresets() {
        let options = CategoryCatalog.options(usedCategories: ["ニュース"])
        XCTAssertEqual(options, CategoryCatalog.presets + ["ニュース"])
    }

    func testCustomCategoriesAreSortedByName() {
        let options = CategoryCatalog.options(usedCategories: ["ニュース", "AI", "書籍"])
        let customs = options.dropFirst(CategoryCatalog.presets.count)
        XCTAssertEqual(Array(customs), ["AI", "ニュース", "書籍"])
    }

    func testCategoriesAlreadyInThePresetsAreNotDuplicated() {
        let options = CategoryCatalog.options(usedCategories: ["音楽", "音楽", "エンタメ"])
        XCTAssertEqual(options, CategoryCatalog.presets)
    }

    func testDuplicateCustomCategoriesCollapseToOneEntry() {
        let options = CategoryCatalog.options(usedCategories: ["ニュース", "ニュース"])
        XCTAssertEqual(options.filter { $0 == "ニュース" }.count, 1)
    }

    func testCategoriesDifferingOnlyByCaseCollapseToOneEntry() {
        let options = CategoryCatalog.options(usedCategories: ["AI", "ai"])
        let customs = options.dropFirst(CategoryCatalog.presets.count)
        XCTAssertEqual(customs.count, 1)
    }

    func testSelectedCategoryStaysInTheOptionsEvenWhenUnused() {
        let options = CategoryCatalog.options(usedCategories: [], selected: "廃止予定")
        XCTAssertTrue(options.contains("廃止予定"))
    }

    func testSelectedCategoryIsNotDuplicatedWhenAlreadyUsed() {
        let options = CategoryCatalog.options(usedCategories: ["ニュース"], selected: "ニュース")
        XCTAssertEqual(options.filter { $0 == "ニュース" }.count, 1)
    }

    func testBlankCategoriesAreIgnored() {
        let options = CategoryCatalog.options(usedCategories: ["", "   ", "\n"], selected: " ")
        XCTAssertEqual(options, CategoryCatalog.presets)
    }

    func testSurroundingWhitespaceIsTrimmedInOptions() {
        let options = CategoryCatalog.options(usedCategories: ["  ニュース  "])
        XCTAssertEqual(options, CategoryCatalog.presets + ["ニュース"])
    }

    // MARK: - 入力値の検証

    func testValidInputIsAccepted() {
        XCTAssertEqual(
            CategoryCatalog.validate("ニュース", existing: CategoryCatalog.presets),
            .accepted("ニュース")
        )
    }

    func testInputIsTrimmedBeforeBeingAccepted() {
        XCTAssertEqual(
            CategoryCatalog.validate("  ニュース \n", existing: []),
            .accepted("ニュース")
        )
    }

    func testEmptyInputIsRejected() {
        guard case .failure(let message) = CategoryCatalog.validate("", existing: []) else {
            return XCTFail("空文字は却下されるべきです")
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testWhitespaceOnlyInputIsRejected() {
        guard case .failure = CategoryCatalog.validate("   \n ", existing: []) else {
            return XCTFail("空白のみの入力は却下されるべきです")
        }
    }

    func testInputAtTheLengthLimitIsAccepted() {
        let name = String(repeating: "あ", count: CategoryCatalog.maxNameLength)
        XCTAssertEqual(CategoryCatalog.validate(name, existing: []), .accepted(name))
    }

    func testInputOverTheLengthLimitIsRejected() {
        let name = String(repeating: "あ", count: CategoryCatalog.maxNameLength + 1)
        guard case .failure(let message) = CategoryCatalog.validate(name, existing: []) else {
            return XCTFail("上限超過は却下されるべきです")
        }
        XCTAssertTrue(
            message.contains("\(CategoryCatalog.maxNameLength)"),
            "エラーメッセージに上限文字数を含めるべきです"
        )
    }

    func testExistingSpellingIsReusedWhenOnlyTheCaseDiffers() {
        XCTAssertEqual(
            CategoryCatalog.validate("ai", existing: ["AI", "音楽"]),
            .accepted("AI")
        )
    }

    func testExistingPresetIsReusedInsteadOfCreatingADuplicate() {
        XCTAssertEqual(
            CategoryCatalog.validate("  音楽  ", existing: CategoryCatalog.presets),
            .accepted("音楽")
        )
    }
}
