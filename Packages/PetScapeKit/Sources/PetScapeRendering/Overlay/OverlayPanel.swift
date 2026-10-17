import AppKit
import PetScapeCore

/// Transparent, borderless, never-key panel covering one screen, just below the Dock
/// (macos-integration.md#overlay-window-configuration, ADR-0003). Click-through by default.
public final class OverlayPanel: NSPanel {
    /// `dockWindow − 1` (19): above normal, floating and modal windows; a revealed auto-hide Dock and
    /// magnified Dock icons draw over the pet (PoC Dock test 5b). Never above the menu bar.
    public static let overlayLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)

    /// Visible on every Space, static in Mission Control, not in Cmd-` cycling. **No**
    /// `.fullScreenAuxiliary`; full-screen Spaces are handled by the full-screen Space rule.
    public static let overlayCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle,
    ]

    public init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = Self.overlayLevel
        collectionBehavior = Self.overlayCollectionBehavior
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        animationBehavior = .none
        // Pets are decorative (NFR-10).
        setAccessibilityElement(false)
    }

    // Never steal keyboard focus or become the main window (NFR-04).
    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }
}
