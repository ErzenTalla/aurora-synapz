import XCTest

extension XCUIApplication {
    /// Signs out via the Account tab if a previous test left a session in the Keychain
    /// (Simulator Keychain persists across app launches/reinstalls).
    func signOutIfNeeded() {
        guard tabBars.buttons["Overview"].waitForExistence(timeout: 3) else { return }
        navigateToTab("Account")
        buttons["SIGN OUT"].tap()
    }

    func login(email: String, password: String) {
        signOutIfNeeded()

        let emailField = textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(password)

        buttons["SIGN IN TO PORTAL"].tap()

        XCTAssertTrue(tabBars.buttons["Overview"].waitForExistence(timeout: 10))
    }

    /// Taps a tab directly if visible, otherwise goes through "More" (tabs overflow on iPhone).
    func navigateToTab(_ name: String) {
        let direct = tabBars.buttons[name]
        if direct.waitForExistence(timeout: 2) {
            direct.tap()
            return
        }
        tabBars.buttons["More"].tap()
        let row = tables.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }
}
