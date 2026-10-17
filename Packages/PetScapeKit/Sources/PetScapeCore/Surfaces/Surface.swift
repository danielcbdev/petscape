import CoreGraphics
import Foundation

/// A walkable horizontal segment in canonical global space (surface-detection.md). Pets stand on it with
/// their contact point on the segment.
///
/// Only horizontal surfaces exist so far; orientation, walkable side, movement hints and source are added with
/// the surfaces that need them (walls M11, windows M12).
public struct Surface: Equatable, Sendable {
    public var id: SurfaceID
    public var kind: SurfaceKind
    /// Left to right, at constant y.
    public private(set) var segment: Segment

    /// A horizontal surface at `y` spanning `minX…maxX` (the ends may be given in either order).
    public init(id: SurfaceID, kind: SurfaceKind, y: CGFloat, minX: CGFloat, maxX: CGFloat) {
        self.id = id
        self.kind = kind
        segment = Segment(start: CGPoint(x: min(minX, maxX), y: y), end: CGPoint(x: max(minX, maxX), y: y))
    }

    /// The bottom edge of `screen`, full width.
    public static func screenBottom(of screen: ScreenDescriptor) -> Surface {
        Surface(
            id: .screenBottom(of: screen.id), kind: .screenBottom, y: screen.frame.minY, minX: screen.frame.minX,
            maxX: screen.frame.maxX)
    }

    public var y: CGFloat { segment.start.y }
    public var minX: CGFloat { segment.start.x }
    public var maxX: CGFloat { segment.end.x }
    public var width: CGFloat { maxX - minX }

    /// The point at `parameter` (0 = left end, 1 = right end); not clamped.
    public func point(atParameter parameter: Double) -> CGPoint {
        CGPoint(x: minX + CGFloat(parameter) * width, y: y)
    }

    /// The parameter of `x` along the surface (0 for a zero-width surface); not clamped.
    public func parameter(atX x: CGFloat) -> Double {
        width > 0 ? Double((x - minX) / width) : 0
    }

    /// The x range a pet's contact point may use so that a sprite extending `margin` to each side stays on the
    /// surface (FR-08). A surface narrower than the sprite yields its midpoint only.
    public func walkableRange(margin: CGFloat) -> ClosedRange<CGFloat> {
        let lower = minX + margin
        let upper = maxX - margin
        guard lower <= upper else {
            let middle = minX + width / 2
            return middle...middle
        }
        return lower...upper
    }
}
