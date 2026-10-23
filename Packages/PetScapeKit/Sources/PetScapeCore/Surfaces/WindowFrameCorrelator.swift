import CoreGraphics
import Foundation

/// Best-effort public-API correlation when AX does not expose a CGWindowID.
public enum WindowFrameCorrelator {
    public enum Result: Equatable, Sendable {
        case matched(UInt32)
        case noMatch
        case ambiguous
    }

    /// Requires one uniquely closest same-process frame within `tolerance` on every edge.
    public static func match(
        ownerPID: Int32, frame: CGRect, windows: [TrackedWindow], tolerance: CGFloat
    ) -> Result {
        guard valid(frame), tolerance.isFinite, tolerance >= 0 else { return .noMatch }
        let candidates = windows.compactMap { window -> (UInt32, CGFloat)? in
            guard window.ownerPID == ownerPID, valid(window.frame) else { return nil }
            let dx0 = abs(frame.minX - window.frame.minX)
            let dy0 = abs(frame.minY - window.frame.minY)
            let dw = abs(frame.width - window.frame.width)
            let dh = abs(frame.height - window.frame.height)
            guard max(dx0, dy0, dw, dh) <= tolerance else { return nil }
            return (window.id, dx0 + dy0 + dw + dh)
        }.sorted { $0.1 < $1.1 }
        guard let first = candidates.first else { return .noMatch }
        if candidates.count > 1, abs(candidates[1].1 - first.1) < 0.001 { return .ambiguous }
        return .matched(first.0)
    }

    private static func valid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
