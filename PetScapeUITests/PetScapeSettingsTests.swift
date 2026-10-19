import XCTest

/// Uses an isolated preferences suite AND a fake login service; Restore Defaults never changes the owner.
final class PetScapeSettingsTests: XCTestCase {
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
        statusItem.click()
        // SwiftUI also exposes Settings… in the app menu, so select the status-menu copy.
        let settings = app.menuItems
            .matching(NSPredicate(format: "title == %@", "Settings…"))
            .element(boundBy: 1)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.click()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let autonomy = window.switches["settings.autonomy"]
        XCTAssertTrue(autonomy.waitForExistence(timeout: 5))
        XCTAssertEqual(integerValue(of: autonomy), 1)
        autonomy.click()
        XCTAssertEqual(integerValue(of: autonomy), 0)
        let size = window.sliders["settings.scale"]
        XCTAssertTrue(size.exists)
        size.adjust(toNormalizedSliderPosition: 0)
        let changedSize = String(describing: size.value)
        window.buttons["Restore Defaults"].click()
        XCTAssertEqual(integerValue(of: autonomy), 1)
        XCTAssertNotEqual(String(describing: size.value), changedSize)
        XCTAssertEqual(integerValue(of: window.switches["settings.login"]), 0)
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(window.exists)
        statusItem.click()
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }
}
