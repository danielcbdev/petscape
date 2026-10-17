import CoreGraphics
import Foundation

/// A straight segment between two points in canonical global space; the geometry of a `Surface`
/// (surface-detection.md).
public struct Segment: Equatable, Sendable {
    public var start: CGPoint
    public var end: CGPoint

    public init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }

    public var length: CGFloat { hypot(end.x - start.x, end.y - start.y) }
}
