import XCTest

final class AuroraQATests: XCTestCase {
    private let secret = "3c7f9ea4fd5b9377dac5148f419bb3d09752ec473643fc2bf15e5f3399d557fe"
    private let base = "https://omnia-aurora.vercel.app"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func addPermissionAllowMonitor() -> NSObjectProtocol {
        addUIInterruptionMonitor(withDescription: "System permission alert") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
    }

    // Navigate to Chat tab and wait for the input bar (requires today's briefing in Blob)
    private func openChatTab(_ app: XCUIApplication) {
        app.tabBars.buttons["Chat"].tap()
        app.tap()
    }

    // Send a typed message in the Chat tab. Call after openChatTab.
    private func sendChatMessage(_ app: XCUIApplication, text: String) {
        let field = app.textViews.matching(identifier: "Ask Aurora…").firstMatch
        let fallback = app.textFields["Ask Aurora…"]
        let input = field.exists ? field : fallback
        XCTAssertTrue(input.waitForExistence(timeout: 8), "Chat input bar must be visible")
        input.tap()
        input.typeText(text)
        let sendBtn = app.buttons["Send message"]
        XCTAssertTrue(sendBtn.waitForExistence(timeout: 5))
        sendBtn.tap()
    }

    // MARK: - Chat: normal reply (no pendingAction)

    func testChatNormalMessageReply() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        openChatTab(app)

        // Briefing must exist — if not, we get the empty state
        let inputExists = app.textViews.matching(identifier: "Ask Aurora…").firstMatch.waitForExistence(timeout: 8)
            || app.textFields["Ask Aurora…"].waitForExistence(timeout: 1)
        XCTAssertTrue(inputExists, "Chat input bar should be visible — ensure today's briefing exists in Blob")

        sendChatMessage(app, text: "What are my open tasks right now?")

        // Wait up to 20s for at least one assistant reply bubble
        let donePredicate = NSPredicate(format: "count >= 2")
        let bubblesExpectation = XCTNSPredicateExpectation(predicate: donePredicate, object: app.staticTexts)
        let result = XCTWaiter().wait(for: [bubblesExpectation], timeout: 20)
        XCTAssertEqual(result, .completed, "Expected at least 2 message bubbles (user + assistant) within 20s")

        // No confirmation banner should appear for a normal question
        XCTAssertFalse(app.staticTexts["Add task:"].exists, "Normal question should not trigger a confirmation banner")

        removeUIInterruptionMonitor(monitor)
    }

    // MARK: - Chat: task confirm flow

    func testChatTaskConfirmAndVerify() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        openChatTab(app)

        let inputExists = app.textViews.matching(identifier: "Ask Aurora…").firstMatch.waitForExistence(timeout: 8)
            || app.textFields["Ask Aurora…"].waitForExistence(timeout: 1)
        XCTAssertTrue(inputExists, "Chat input bar must be visible")

        sendChatMessage(app, text: "Add a QA smoke test task")

        // Wait for confirmation banner
        let banner = app.staticTexts["Add task:"]
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "Confirmation banner should appear after task-intent message")

        let confirmBtn = app.buttons["Confirm"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 5))
        confirmBtn.tap()

        // Banner should disappear
        XCTAssertTrue(banner.waitForNonExistence(timeout: 8), "Banner should be gone after confirming")

        // "Done" message should appear
        let donePredicate = NSPredicate(format: "label CONTAINS 'Done'")
        let doneMsg = app.staticTexts.matching(donePredicate).firstMatch
        XCTAssertTrue(doneMsg.waitForExistence(timeout: 8), "A 'Done' confirmation message should appear after task is created")

        removeUIInterruptionMonitor(monitor)
    }

    // MARK: - Chat: task cancel flow

    func testChatTaskCancel() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        openChatTab(app)

        let inputExists = app.textViews.matching(identifier: "Ask Aurora…").firstMatch.waitForExistence(timeout: 8)
            || app.textFields["Ask Aurora…"].waitForExistence(timeout: 1)
        XCTAssertTrue(inputExists, "Chat input bar must be visible")

        sendChatMessage(app, text: "Add a task called aurora cancel smoke test")

        let banner = app.staticTexts["Add task:"]
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "Confirmation banner should appear")

        app.buttons["Cancel"].tap()

        XCTAssertTrue(banner.waitForNonExistence(timeout: 3), "Banner should disappear immediately after Cancel")
        XCTAssertFalse(app.buttons["Confirm"].exists, "Confirm button should be gone after cancelling")

        removeUIInterruptionMonitor(monitor)
    }

    // MARK: - Workspace: notes add & delete

    func testNotesAddDelete() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        app.tabBars.buttons["Workspace"].tap()
        app.tap()

        // Switch to Notes segment
        let notesSegment = app.segmentedControls.firstMatch.buttons["Notes"]
        XCTAssertTrue(notesSegment.waitForExistence(timeout: 8))
        notesSegment.tap()

        let addBtn = app.buttons["Open Add Sheet"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 8))
        addBtn.tap()

        let noteText = "QA note \(Int(Date().timeIntervalSince1970))"
        let textField = app.textFields["What's on your mind?"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText(noteText)

        app.buttons["Add"].tap()

        let noteRow = app.staticTexts[noteText]
        XCTAssertTrue(noteRow.waitForExistence(timeout: 8), "Newly added note should appear in the list")

        noteRow.swipeLeft()
        let deleteBtn = app.buttons["Delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 5))
        deleteBtn.tap()

        XCTAssertTrue(noteRow.waitForNonExistence(timeout: 8), "Deleted note should disappear")

        removeUIInterruptionMonitor(monitor)
    }

    // MARK: - Workspace: knowledge add & delete

    func testKnowledgeAddDelete() throws {
        let app = XCUIApplication()
        let monitor = addPermissionAllowMonitor()
        app.launch()

        app.tabBars.buttons["Workspace"].tap()
        app.tap()

        // Switch to Knowledge segment
        let knowledgeSegment = app.segmentedControls.firstMatch.buttons["Knowledge"]
        XCTAssertTrue(knowledgeSegment.waitForExistence(timeout: 8))
        knowledgeSegment.tap()

        let addBtn = app.buttons["Open Add Sheet"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 8))
        addBtn.tap()

        let factText = "QA fact \(Int(Date().timeIntervalSince1970))"
        let textField = app.textFields["What's on your mind?"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText(factText)

        app.buttons["Add"].tap()

        let factRow = app.staticTexts[factText]
        XCTAssertTrue(factRow.waitForExistence(timeout: 8), "Newly added fact should appear in the list")

        factRow.swipeLeft()
        let deleteBtn = app.buttons["Delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 5))
        deleteBtn.tap()

        XCTAssertTrue(factRow.waitForNonExistence(timeout: 8), "Deleted fact should disappear")

        removeUIInterruptionMonitor(monitor)
    }
}
