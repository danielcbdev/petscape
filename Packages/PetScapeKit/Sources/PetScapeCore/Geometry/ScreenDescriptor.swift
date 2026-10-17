import CoreGraphics
import Foundation

/// One display as seen by the domain, in canonical AppKit global points (coordinate-system.md).
/// Produced by the Platform `ScreenProvider`; Core never touches `NSScreen`.
public struct ScreenDescriptor: Equatable, Sendable {
    public var id: ScreenID
    /// Full screen frame, global points (y-up, origin = primary screen bottom-left).
    public var frame: CGRect
    /// Frame minus the menu bar and the Dock reservation, global points.
    public var visibleFrame: CGRect
    /// Points → pixels factor (1.0, 2.0, …).
    public var backingScale: Double
    /// The screen at the global origin (`NSScreen.screens.first`), not the key window's screen.
    public var isPrimary: Bool

    public init(id: ScreenID, frame: CGRect, visibleFrame: CGRect, backingScale: Double, isPrimary: Bool) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.backingScale = backingScale
        self.isPrimary = isPrimary
    }
}
