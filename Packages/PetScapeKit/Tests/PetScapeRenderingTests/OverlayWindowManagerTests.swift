import AppKit
import Testing

@testable import PetScapeCore
@testable import PetScapeRendering

@Suite("OverlayWindowManager")
struct OverlayWindowManagerTests {
    static func screen(_ id: UInt32, x: CGFloat, width: CGFloat = 800) -> ScreenDescriptor {
        let frame = CGRect(x: x, y: 0, width: width, height: 600)
        return ScreenDescriptor(
            id: ScreenID(id), frame: frame, visibleFrame: frame, backingScale: 2, isPrimary: id == 1)
    }

    @Test func createsPanelsOnlyForHostingScreensWithTheirFrames() {
        let manager = OverlayWindowManager(notificationCenter: NotificationCenter())
        defer { manager.removeAll() }
        let screens = [Self.screen(1, x: 0), Self.screen(2, x: 800)]
        manager.update(screens: screens, hosting: [ScreenID(1)])

        #expect(manager.screenIDs == [ScreenID(1)])
        #expect(manager.panel(for: ScreenID(1))?.frame == screens[0].frame)
        #expect(manager.contentView(for: ScreenID(1)) != nil)
        #expect(manager.panel(for: ScreenID(2)) == nil)
    }

    @Test func followsFrameChangesAndRemovesVanishedScreens() {
        let manager = OverlayWindowManager(notificationCenter: NotificationCenter())
        defer { manager.removeAll() }
        manager.update(screens: [Self.screen(1, x: 0), Self.screen(2, x: 800)], hosting: [ScreenID(1), ScreenID(2)])
        let firstPanel = manager.panel(for: ScreenID(1))

        // Resolution change on screen 1, screen 2 disconnected.
        let resized = Self.screen(1, x: 0, width: 1024)
        manager.update(screens: [resized], hosting: [ScreenID(1), ScreenID(2)])

        #expect(manager.screenIDs == [ScreenID(1)])
        #expect(manager.panel(for: ScreenID(1)) === firstPanel)  // re-laid out, not recreated
        #expect(manager.panel(for: ScreenID(1))?.frame == resized.frame)
    }

    @Test func passThroughAndVisibilityApplyToExistingAndNewPanels() {
        let manager = OverlayWindowManager(notificationCenter: NotificationCenter())
        defer { manager.removeAll() }
        manager.update(screens: [Self.screen(1, x: 0)], hosting: [ScreenID(1)])
        #expect(manager.panel(for: ScreenID(1))?.ignoresMouseEvents == true)

        manager.setIgnoresMouseEvents(false)
        #expect(manager.panel(for: ScreenID(1))?.ignoresMouseEvents == false)

        manager.update(screens: [Self.screen(1, x: 0), Self.screen(2, x: 800)], hosting: [ScreenID(1), ScreenID(2)])
        #expect(manager.panel(for: ScreenID(2))?.ignoresMouseEvents == false)

        manager.setVisible(false)
        #expect(manager.panel(for: ScreenID(1))?.isVisible == false)
        #expect(!manager.isVisible)
    }

    @Test func removeAllClosesEverything() {
        let manager = OverlayWindowManager(notificationCenter: NotificationCenter())
        manager.update(screens: [Self.screen(1, x: 0)], hosting: [ScreenID(1)])
        let panel = manager.panel(for: ScreenID(1))
        manager.removeAll()
        #expect(manager.screenIDs.isEmpty)
        #expect(panel?.isVisible == false)
    }
}
