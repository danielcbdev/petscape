import CoreGraphics
import Foundation

/// A point in Quartz global space (origin = primary display top-left, y down), as returned by
/// `CGWindowList`, AX and `CGEvent`. Wrapped so it cannot be mistaken for a canonical point; it must be
/// converted by `CoordinateConverter` inside the Platform adapter that read it (ADR-0008).
public struct QuartzPoint: Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// A rectangle in Quartz global space (origin = its top-left corner, y down). See `QuartzPoint`.
public struct QuartzRect: Equatable, Sendable {
    public var origin: QuartzPoint
    public var size: CGSize

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        origin = QuartzPoint(x: x, y: y)
        size = CGSize(width: width, height: height)
    }
}
