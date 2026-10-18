import CoreGraphics
import Foundation

/// The Dock heuristic of ADR-0009 (surface-detection.md#dock-geometry-estimation): the Dock's position comes
/// from the largest bottom/left/right reservation of any screen's visible frame, and the pet's walkway from that
/// estimate. Pure: fed with `ScreenDescriptor`s, so every case is unit-tested.
public enum DockGeometryEstimator {
    /// Smallest reservation that counts as a visible Dock (PoC E3: visible Docks reserved 42–65 pt at the bottom
    /// and 49 pt on a side; auto-hide reserved exactly 0 pt).
    public static let minimumInset: CGFloat = 10

    /// Allowed values of the `dockOffsetAdjustment` preference, in points.
    public static let offsetAdjustmentRange: ClosedRange<Double> = -40...40

    /// The edge and screen with the largest reservation, if it reaches `minimumInset`. Ties keep the first
    /// screen, then bottom before left before right. The top inset (menu bar) is never a candidate.
    public static func estimate(screens: [ScreenDescriptor]) -> DockEstimate {
        var best = DockEstimate.hiddenOrUnknown
        for screen in screens {
            let frame = screen.frame
            let visible = screen.visibleFrame
            let candidates: [(DockEstimate.Position, CGFloat, CGFloat)] = [
                (.bottom, visible.minY - frame.minY, visible.minY),
                (.left, visible.minX - frame.minX, visible.minX),
                (.right, frame.maxX - visible.maxX, visible.maxX),
            ]
            for (position, inset, edgeLine) in candidates where inset >= minimumInset && inset > best.thickness {
                best = DockEstimate(position: position, screenID: screen.id, thickness: inset, edgeLine: edgeLine)
            }
        }
        return best
    }

    /// The walkway for `estimate` (surface-detection.md#surface-selection):
    ///
    /// - bottom Dock: `.dockTop` at `edgeLine + offsetAdjustment` (clamped to `offsetAdjustmentRange`), spanning the
    ///   Dock screen's full width — the shelf's horizontal extent is unknown, and the world keeps the sprite inside
    ///   with its edge margin (FR-08);
    /// - side Dock: the bottom of the Dock's screen;
    /// - hidden or unknown (or a screen that is gone): the bottom of the primary screen.
    ///
    /// `nil` only without screens.
    public static func surface(
        for estimate: DockEstimate, screens: [ScreenDescriptor], offsetAdjustment: Double
    ) -> Surface? {
        let dockScreen = estimate.screenID.flatMap { id in screens.first { $0.id == id } }
        switch (estimate.position, dockScreen, estimate.edgeLine) {
        case (.bottom, let screen?, let edgeLine?):
            return Surface(
                id: .dock, kind: .dockTop, y: edgeLine + CGFloat(clampedOffset(offsetAdjustment)),
                minX: screen.frame.minX, maxX: screen.frame.maxX)
        case (.left, let screen?, _), (.right, let screen?, _):
            return .screenBottom(of: screen)
        default:
            return (screens.first { $0.isPrimary } ?? screens.first).map(Surface.screenBottom(of:))
        }
    }

    /// `offset` limited to `offsetAdjustmentRange` (0 for a non-finite value).
    public static func clampedOffset(_ offset: Double) -> Double {
        guard offset.isFinite else { return 0 }
        return min(max(offset, offsetAdjustmentRange.lowerBound), offsetAdjustmentRange.upperBound)
    }
}
