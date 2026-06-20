import XCTest

final class ClientFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// Logs in fresh regardless of whether a previous test left a session in the Keychain
    /// (Simulator Keychain persists across app launches/reinstalls).
    func ensureLoggedIn() {
        if app.tabBars.buttons["Overview"].waitForExistence(timeout: 3) {
            navigateToTab("Account")
            app.buttons["SIGN OUT"].tap()
        }

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("e2e-ios-test@aurorasyanapz.com")

        let password = app.secureTextFields.firstMatch
        password.tap()
        password.typeText("Test1234!")

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

    func testLoginAndDepositRequestFlow() throws {
        ensureLoggedIn()

        navigateToTab("Deposit")
        let amountField = app.textFields["e.g. 200"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("250")

        app.buttons["SUBMIT DEPOSIT REQUEST"].tap()

        XCTAssertTrue(app.staticTexts["$250"].waitForExistence(timeout: 10))
    }

    func testWithdrawShowsInsufficientFundsError() throws {
        ensureLoggedIn()

        navigateToTab("Withdraw")
        let amountField = app.textFields["e.g. 500"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("1000")

        app.buttons["REQUEST WITHDRAWAL"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'exceeds your available balance'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testDocumentsTabLoadsEmptyState() throws {
        ensureLoggedIn()

        navigateToTab("Documents")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No documents'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testAccountTabShowsFaceIDToggle() throws {
        ensureLoggedIn()

        navigateToTab("Account")
        XCTAssertTrue(app.staticTexts["Face ID Lock"].waitForExistence(timeout: 5))
    }
}
