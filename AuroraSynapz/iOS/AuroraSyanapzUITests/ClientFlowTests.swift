import XCTest

final class ClientFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.login(email: "e2e-ios-test@aurorasyanapz.com", password: "Test1234!")
    }

    func testLoginAndDepositRequestFlow() throws {
        app.navigateToTab("Deposit")
        let amountField = app.textFields["e.g. 200"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("250")

        app.buttons["SUBMIT DEPOSIT REQUEST"].tap()

        XCTAssertTrue(app.staticTexts["$250"].waitForExistence(timeout: 10))
    }

    func testWithdrawShowsInsufficientFundsError() throws {
        app.navigateToTab("Withdraw")
        let amountField = app.textFields["e.g. 500"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("1000")

        app.buttons["REQUEST WITHDRAWAL"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'exceeds your available balance'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testDocumentsTabLoadsEmptyState() throws {
        app.navigateToTab("Documents")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No documents'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testAccountTabShowsFaceIDToggle() throws {
        app.navigateToTab("Account")
        XCTAssertTrue(app.staticTexts["Face ID Lock"].waitForExistence(timeout: 5))
    }
}
