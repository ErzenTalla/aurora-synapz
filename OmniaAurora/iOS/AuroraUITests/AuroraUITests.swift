import XCTest

final class AuroraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func addPermissionAllowMonitor() -> NSObjectProtocol {
        addUIInterruptionMonitor(withDescription: "System permission alert") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists {
                allow.tap()
                return true
            }
            return false
        }
    }

    func testHistoryChatProfileTabsLoad() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready to talk through today?"].waitForExistence(timeout: 5))

        app.tabBars.buttons["History"].tap()
        app.tap()
        let historyLoaded = app.buttons["2026-06-18"].waitForExistence(timeout: 8)
            || app.staticTexts["No briefings saved yet."].waitForExistence(timeout: 1)
        XCTAssertTrue(historyLoaded, "History tab should show either a saved briefing or the empty state")

        app.tabBars.buttons["Chat"].tap()
        app.tap()
        let chatReady = app.textFields["Ask Aurora…"].waitForExistence(timeout: 8)
            || app.staticTexts["Generate today's briefing on the Today tab first — then come back here to ask Aurora about it."].waitForExistence(timeout: 1)
        XCTAssertTrue(chatReady, "Chat tab should show either the input bar or the empty state")

        app.tabBars.buttons["Profile"].tap()
        app.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 8), "Profile tab should show the editable profile text")
        XCTAssertTrue(app.buttons["Save"].exists)

        removeUIInterruptionMonitor(monitor)
    }

    func testTodayFlowAdvancesByTyping() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        app.tap()

        XCTAssertTrue(app.staticTexts["Question 1 of 6"].waitForExistence(timeout: 8))
        let answerField = app.textFields["Answer"]
        XCTAssertTrue(answerField.waitForExistence(timeout: 5))
        answerField.tap()
        answerField.typeText("Quick smoke test answer")

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Question 2 of 6"].waitForExistence(timeout: 5), "Tapping Next should advance to question 2 even while Aurora is still speaking question 1")

        removeUIInterruptionMonitor(monitor)
    }

    func testWorkspaceAddCompleteDeleteTask() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        app.tabBars.buttons["Workspace"].tap()
        app.tap()

        let addButton = app.navigationBars.buttons["plus"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8), "Workspace should show an add button once Tasks have loaded")
        addButton.tap()

        let taskText = "UITest task \(Int(Date().timeIntervalSince1970))"
        let textField = app.textFields["What's on your mind?"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText(taskText)

        app.buttons["Add"].tap()

        let taskRow = app.staticTexts[taskText]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 8), "Newly added task should appear in the list")

        taskRow.tap()

        taskRow.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(taskRow.waitForNonExistence(timeout: 8), "Deleted task should disappear from the list")

        removeUIInterruptionMonitor(monitor)
    }
}

extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
