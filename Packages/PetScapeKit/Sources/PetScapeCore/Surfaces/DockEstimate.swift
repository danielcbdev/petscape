import CoreGraphics
import Foundation

/// Where the Dock is, as far as public API tells (surface-detection.md#dock-geometry-estimation, ADR-0009):
/// the screen and edge whose visible frame reserves space for it, or `hiddenOrUnknown` when no screen reserves
/// enough (auto-hide, or no Dock).
public struct DockEstimate: Equatable, Sendable {
    public enum Position: String, Sendable {
        case bottom
        case left
        case right
        case hiddenOrUnknown
    }

    public var position: Position
    /// The screen that reserves the Dock area; `nil` when hidden or unknown.
    public var screenID: ScreenID?
    /// The reserved inset in points (0 when hidden or unknown).
    public var thickness: CGFloat
    /// The inner edge of the reservation in global points: `visibleFrame.minY` for a bottom Dock,
    /// `visibleFrame.minX` (left) or `visibleFrame.maxX` (right) for a side Dock; `nil` when hidden or unknown.
    public var edgeLine: CGFloat?

    public init(position: Position, screenID: ScreenID?, thickness: CGFloat, edgeLine: CGFloat?) {
        self.position = position
        self.screenID = screenID
        self.thickness = thickness
        self.edgeLine = edgeLine
    }

    public static let hiddenOrUnknown = DockEstimate(
        position: .hiddenOrUnknown, screenID: nil, thickness: 0, edgeLine: nil)
}

extension DockEstimate: CustomStringConvertible {
    /// One line for the log (geometry only).
    public var description: String {
        guard let screenID, let edgeLine else { return position.rawValue }
        return "\(position.rawValue) on screen \(screenID), inset \(thickness) pt, edge at \(edgeLine)"
    }
}
