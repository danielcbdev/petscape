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

    public enum Button: Equatable, Sendable {
        case primary
        case secondary
        case other(Int)
    }

    public var kind: Kind
    public var location: CGPoint
    /// System uptime (`NSEvent.timestamp`).
    public var timestamp: TimeInterval
    public var button: Button

    public init(kind: Kind, location: CGPoint, timestamp: TimeInterval, button: Button = .primary) {
        self.kind = kind
        self.location = location
        self.timestamp = timestamp
        self.button = button
    }
}
