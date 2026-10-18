import XCTest

/// Launch smoke test (T2.7, AC-01): the app starts as a menu bar–only app and Quit ends the process.
final class PetScapeLaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsStatusItemAndQuitTerminates() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "PetScape status item not found")
        XCTAssertEqual(app.windows.count, 0, "A menu bar–only app must not open windows")

        statusItem.click()
        let quit = app.menuItems.matching(identifier: "menuAction:").firstMatch
        XCTAssertTrue(quit.waitForExistence(timeout: 5), "Quit PetScape menu item not found")
        app.typeKey("q", modifierFlags: .command)

        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5), "PetScape did not quit")
    }
}
