import XCTest

final class AdminFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// Logs in fresh regardless of whether a previous test left a session in the Keychain.
    func ensureLoggedIn() {
        if app.tabBars.buttons["Overview"].waitForExistence(timeout: 3) {
            navigateToTab("Account")
            app.buttons["SIGN OUT"].tap()
        }

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("erzentalla1@gmail.com")

        let password = app.secureTextFields.firstMatch
        password.tap()
        password.typeText("12345678")

        app.buttons["SIGN IN TO PORTAL"].tap()

        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 10))
    }

    /// Taps a tab directly if visible, otherwise goes through "More" (tabs overflow on iPhone).
    func navigateToTab(_ name: String) {
        let direct = app.tabBars.buttons[name]
        if direct.waitForExistence(timeout: 2) {
            direct.tap()
            return
        }
        app.tabBars.buttons["More"].tap()
        let row = app.tables.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    func testDepositRequestsScreenLoads() throws {
        ensureLoggedIn()

        navigateToTab("Deposits")
        XCTAssertTrue(app.staticTexts["Invest Available Cash"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["All Requests"].waitForExistence(timeout: 5))
    }

    func testWithdrawalsScreenLoads() throws {
        ensureLoggedIn()

        navigateToTab("Withdrawals")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'units are redeemed immediately'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testFeeManagementScreenLoads() throws {
        ensureLoggedIn()

        navigateToTab("Fees")
        XCTAssertTrue(app.staticTexts["Upcoming Fee Preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Client Fee Rates"].waitForExistence(timeout: 5))
    }

    func testDocumentsScreenLoadsAndUploadSheetOpens() throws {
        ensureLoggedIn()

        navigateToTab("Documents")
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))

        app.navigationBars["Documents"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Select a client"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }
}
