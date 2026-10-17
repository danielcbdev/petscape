import CoreGraphics
import Foundation

/// A mouse event received by an overlay while pass-through is off. `location` is canonical global.
public struct OverlayMouseEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case moved
        case down
        case dragged
        case up
    }

    public var kind: Kind
    public var location: CGPoint
    /// System uptime (`NSEvent.timestamp`).
    public var timestamp: TimeInterval

    public init(kind: Kind, location: CGPoint, timestamp: TimeInterval) {
        self.kind = kind
        self.location = location
        self.timestamp = timestamp
    }
}
