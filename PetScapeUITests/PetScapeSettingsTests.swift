import XCTest

/// Uses an isolated preferences suite AND a fake login service; Restore Defaults never changes the owner.
final class PetScapeSettingsTests: XCTestCase {
    @MainActor
    private func integerValue(of element: XCUIElement) -> Int? {
        if let number = element.value as? NSNumber { return number.intValue }
        if let string = element.value as? String { return Int(string) }
        return nil
    }

    @MainActor
    func testSettingsApplyRestoreCloseAndQuit() throws {
        let suiteName = "PetScapeUITests.\(UUID().uuidString)"
        let app = XCUIApplication()
        app.launchArguments = ["--settings-test-suite", suiteName]
        defer {
            if app.state != .notRunning { app.terminate() }
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        // The same Settings title is exposed in the status menu and the system app menu.
        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let windowInteraction = window.switches["settings.windowInteraction"]
        XCTAssertTrue(windowInteraction.waitForExistence(timeout: 5))
        XCTAssertEqual(windowInteraction.label, "Interact with windows")
        XCTAssertEqual(integerValue(of: windowInteraction), 0)
        XCTAssertTrue(window.staticTexts["settings.windowInteractionExplanation"].exists)
        let autonomy = window.switches["settings.autonomy"]
        XCTAssertTrue(autonomy.waitForExistence(timeout: 5))
        XCTAssertEqual(autonomy.label, "Autonomous activities")
        XCTAssertEqual(integerValue(of: autonomy), 1)
        autonomy.click()
        XCTAssertEqual(integerValue(of: autonomy), 0)
        let cursor = window.switches["settings.cursorReactions"]
        XCTAssertTrue(cursor.waitForExistence(timeout: 3))
        XCTAssertEqual(integerValue(of: cursor), 1)
        cursor.click()
        XCTAssertEqual(integerValue(of: cursor), 0)
        let direct = window.switches["settings.directInteraction"]
        XCTAssertTrue(direct.waitForExistence(timeout: 3))
        XCTAssertEqual(integerValue(of: direct), 1)
        direct.click()
        XCTAssertEqual(integerValue(of: direct), 0)
        window.buttons["Restore Defaults"].click()
        XCTAssertEqual(integerValue(of: autonomy), 1)
        XCTAssertEqual(integerValue(of: cursor), 1)
        XCTAssertEqual(integerValue(of: direct), 1)
        XCTAssertEqual(integerValue(of: window.switches["settings.login"]), 0)
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(window.exists)
        statusItem.click()
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }
}
