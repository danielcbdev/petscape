import CoreGraphics
import Foundation

/// Builds visible horizontal window tops from a front-to-back window snapshot.
public enum WindowSurfaceBuilder {
    /// The menu-bar reservation is removed from the top of each screen. Dock reservation is not,
    /// because a window can legitimately overlap that area and M12 surfaces describe window geometry.
    public static func build(windows: [TrackedWindow], screens: [ScreenDescriptor]) -> [Surface] {
        let ordered = windows.sorted { $0.zIndex < $1.zIndex }
        var result: [Surface] = []
        for window in ordered {
            let frame = window.frame
            guard !window.isMinimized, isValid(frame) else { continue }
            var visible: [(screenID: ScreenID, range: ClosedRange<CGFloat>)] = []
            for screen in screens where isValid(screen.frame) && isValid(screen.visibleFrame) {
                let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
                let usableTop = screen.frame.maxY - menuBarHeight
                let top = frame.maxY
                guard top > screen.frame.minY, top <= usableTop else { continue }
                let lower = max(frame.minX, screen.frame.minX)
                let upper = min(frame.maxX, screen.frame.maxX)
                guard upper > lower else { continue }
                var segments = [(lower, upper)]
                for cover in ordered where cover.zIndex < window.zIndex && isValid(cover.frame) {
                    // A front window hides this edge only when its interior crosses the top-edge y.
                    guard cover.frame.minY < top, cover.frame.maxY > top else { continue }
                    segments = segments.flatMap { subtract($0, by: cover.frame.minX...cover.frame.maxX) }
                    if segments.isEmpty { break }
                }
                visible += segments.map { (screen.id, $0.0...$0.1) }
            }
            for (index, segment) in visible.enumerated() {
                result.append(
                    Surface(
                        id: SurfaceID("window:\(window.id):top:\(index)"), kind: .windowTop,
                        y: frame.maxY, minX: segment.range.lowerBound, maxX: segment.range.upperBound))
            }
        }
        return result
    }

    private static func subtract(
        _ source: (CGFloat, CGFloat), by cover: ClosedRange<CGFloat>
    ) -> [(CGFloat, CGFloat)] {
        guard cover.upperBound > source.0, cover.lowerBound < source.1 else { return [source] }
        var result: [(CGFloat, CGFloat)] = []
        if cover.lowerBound > source.0 { result.append((source.0, min(source.1, cover.lowerBound))) }
        if cover.upperBound < source.1 { result.append((max(source.0, cover.upperBound), source.1)) }
        return result.filter { $0.1 - $0.0 > 0 }
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
