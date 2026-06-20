import XCTest

final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToLoginScreen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 5))
    }
}
