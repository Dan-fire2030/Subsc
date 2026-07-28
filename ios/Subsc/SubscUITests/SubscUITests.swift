import XCTest

@MainActor
final class SubscUITests: XCTestCase {
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        return app
    }

    func testCoreAddFlow() {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()

        app.buttons["add-subscription-button"].tap()
        let nameField = app.textFields["subscription-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test Service")

        let amountField = app.textFields["subscription-amount-field"]
        amountField.tap()
        amountField.typeText("1200")

        let notificationsSwitch = app.switches["通知"]
        for _ in 0..<5 where !notificationsSwitch.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(notificationsSwitch.isHittable)
        notificationsSwitch.tap()
        app.buttons["subscription-save-button"].tap()

        XCTAssertTrue(app.staticTexts["Test Service"].waitForExistence(timeout: 3))
    }

    func testReturningToTheCurrentMonthFromAnotherMonth() {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        addSubscription(named: "Pager Service", amount: "1000", in: app)

        let nextMonth = app.buttons["次の月"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5))

        let returnToCurrentMonth = app.buttons["今月へ戻る"]
        XCTAssertFalse(
            returnToCurrentMonth.exists,
            "今月を表示している間は復帰ボタンを出しません"
        )

        nextMonth.tap()
        XCTAssertTrue(returnToCurrentMonth.waitForExistence(timeout: 3))

        returnToCurrentMonth.tap()
        XCTAssertTrue(returnToCurrentMonth.waitForNonExistence(timeout: 3))
    }

    private func addSubscription(
        named name: String,
        amount: String,
        in app: XCUIApplication
    ) {
        app.buttons["add-subscription-button"].tap()

        let nameField = app.textFields["subscription-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)

        let amountField = app.textFields["subscription-amount-field"]
        amountField.tap()
        amountField.typeText(amount)

        app.buttons["subscription-save-button"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    func testAccessibilityAuditAtDefaultTextSize() throws {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.buttons["add-subscription-button"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit()
    }

    func testLaunchAtLargestAccessibilityTextSize() {
        continueAfterFailure = false
        let app = makeApp()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["add-subscription-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.buttons["empty-state-add-subscription-button"]
                .waitForExistence(timeout: 3)
        )
    }
}
