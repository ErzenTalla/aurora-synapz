import XCTest

final class AdminFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.login(email: "erzentalla1@gmail.com", password: "12345678")
    }

    func testDepositRequestsScreenLoads() throws {
        app.navigateToTab("Deposits")
        XCTAssertTrue(app.staticTexts["Invest Available Cash"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["All Requests"].waitForExistence(timeout: 5))
    }

    func testWithdrawalsScreenLoads() throws {
        app.navigateToTab("Withdrawals")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'units are redeemed immediately'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testFeeManagementScreenLoads() throws {
        app.navigateToTab("Fees")
        XCTAssertTrue(app.staticTexts["Upcoming Fee Preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Client Fee Rates"].waitForExistence(timeout: 5))
    }

    func testDocumentsScreenLoadsAndUploadSheetOpens() throws {
        app.navigateToTab("Documents")
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))

        app.navigationBars["Documents"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Select a client"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }
}
