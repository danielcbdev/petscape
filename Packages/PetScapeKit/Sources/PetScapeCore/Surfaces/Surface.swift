import CoreGraphics
import Foundation

/// A walkable horizontal or climbable vertical segment in canonical global space.
///
public struct Surface: Equatable, Sendable {
    public var id: SurfaceID
    public var kind: SurfaceKind
    /// Left to right, at constant y.
    public private(set) var segment: Segment

    public var isVertical: Bool { segment.start.x == segment.end.x }

    /// A horizontal surface at `y` spanning `minX…maxX` (the ends may be given in either order).
    public init(id: SurfaceID, kind: SurfaceKind, y: CGFloat, minX: CGFloat, maxX: CGFloat) {
        self.id = id
        self.kind = kind
        segment = Segment(start: CGPoint(x: min(minX, maxX), y: y), end: CGPoint(x: max(minX, maxX), y: y))
    }

    /// A vertical segment at `x`, with endpoints normalized bottom to top.
    public init(id: SurfaceID, kind: SurfaceKind, x: CGFloat, minY: CGFloat, maxY: CGFloat) {
        self.id = id
        self.kind = kind
        segment = Segment(start: CGPoint(x: x, y: min(minY, maxY)), end: CGPoint(x: x, y: max(minY, maxY)))
    }

    /// The bottom edge of `screen`, full width.
    public static func screenBottom(of screen: ScreenDescriptor) -> Surface {
        Surface(
            id: .screenBottom(of: screen.id), kind: .screenBottom, y: screen.frame.minY, minX: screen.frame.minX,
            maxX: screen.frame.maxX)
    }

    public static func screenLeft(of screen: ScreenDescriptor) -> Surface {
        Surface(
            id: .screenLeft(of: screen.id), kind: .screenLeft, x: screen.frame.minX,
            minY: screen.frame.minY, maxY: screen.frame.maxY)
    }

    public static func screenRight(of screen: ScreenDescriptor) -> Surface {
        Surface(
            id: .screenRight(of: screen.id), kind: .screenRight, x: screen.frame.maxX,
            minY: screen.frame.minY, maxY: screen.frame.maxY)
    }

    public var y: CGFloat { segment.start.y }
    public var minX: CGFloat { segment.start.x }
    public var maxX: CGFloat { segment.end.x }
    public var width: CGFloat { maxX - minX }
    public var minY: CGFloat { segment.start.y }
    public var maxY: CGFloat { segment.end.y }
    public var height: CGFloat { maxY - minY }

    /// Invalid environment geometry is never a support or a recovery destination.
    var isUsable: Bool {
        segment.start.x.isFinite && segment.start.y.isFinite && segment.end.x.isFinite && segment.end.y.isFinite
            && (isVertical ? height.isFinite && height > 0 : width.isFinite && width > 0)
    }

    /// The point at `parameter` (0 = left end, 1 = right end); not clamped.
    public func point(atParameter parameter: Double) -> CGPoint {
        CGPoint(
            x: segment.start.x + CGFloat(parameter) * (segment.end.x - segment.start.x),
            y: segment.start.y + CGFloat(parameter) * (segment.end.y - segment.start.y))
    }

    /// The parameter of `x` along the surface (0 for a zero-width surface); not clamped.
    public func parameter(atX x: CGFloat) -> Double {
        width > 0 ? Double((x - minX) / width) : 0
    }

    public func parameter(atY y: CGFloat) -> Double {
        height > 0 ? Double((y - minY) / height) : 0
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
