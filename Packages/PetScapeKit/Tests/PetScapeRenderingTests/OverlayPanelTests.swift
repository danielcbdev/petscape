import AppKit
import Testing

@testable import PetScapeRendering

/// Configuration values of macos-integration.md#overlay-window-configuration (T3.3).
@Suite("OverlayPanel configuration")
struct OverlayPanelTests {
    @Test func matchesTheSpecifiedConfiguration() {
        let frame = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let panel = OverlayPanel(frame: frame)
        defer { panel.close() }

        #expect(panel.styleMask == [.borderless, .nonactivatingPanel])
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(!panel.isOpaque)
        #expect(panel.backgroundColor == .clear)
        #expect(!panel.hasShadow)
        #expect(panel.level.rawValue == Int(CGWindowLevelForKey(.dockWindow)) - 1)
        #expect(panel.level.rawValue < Int(CGWindowLevelForKey(.mainMenuWindow)))
        #expect(panel.collectionBehavior == [.canJoinAllSpaces, .stationary, .ignoresCycle])
        #expect(!panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isReleasedWhenClosed)
        #expect(!panel.hidesOnDeactivate)
        #expect(!panel.isAccessibilityElement())
        #expect(panel.frame == frame)
    }

    @Test func contentViewIsLayerBackedClearAndNotFlipped() throws {
        let view = OverlayContentView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let layer = try #require(view.layer)
        #expect(view.wantsLayer)
        #expect(!view.isFlipped)
        #expect(layer.backgroundColor == CGColor.clear)
        #expect(!layer.isOpaque)
        #expect(view.acceptsFirstMouse(for: nil))
        #expect(!view.isAccessibilityElement())
    }
}
