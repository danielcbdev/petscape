import CoreGraphics
import Foundation

/// Builds visible horizontal window tops from a front-to-back window snapshot.
public enum WindowSurfaceBuilder {
    private struct VisibleSegment {
        var lower: CGFloat
        var upper: CGFloat
        var lowerBoundary: String
        var upperBoundary: String
    }

    /// The menu-bar reservation is removed from the top of each screen. Dock reservation is not,
    /// because a window can legitimately overlap that area and M12 surfaces describe window geometry.
    public static func build(windows: [TrackedWindow], screens: [ScreenDescriptor]) -> [Surface] {
        let ordered = windows.sorted {
            $0.zIndex == $1.zIndex ? $0.id < $1.id : $0.zIndex < $1.zIndex
        }
        var result: [Surface] = []
        for window in ordered {
            let frame = window.frame
            guard !window.isMinimized, isValid(frame) else { continue }
            var visible: [(screenID: ScreenID, segment: VisibleSegment)] = []
            for screen in screens where isValid(screen.frame) && isValid(screen.visibleFrame) {
                let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
                let usableTop = screen.frame.maxY - menuBarHeight
                let top = frame.maxY
                guard top > screen.frame.minY, top <= usableTop else { continue }
                let lower = max(frame.minX, screen.frame.minX)
                let upper = min(frame.maxX, screen.frame.maxX)
                guard upper > lower else { continue }
                var segments = [
                    VisibleSegment(
                        lower: lower, upper: upper,
                        lowerBoundary: lower == frame.minX ? "window:\(window.id):left" : "screen:\(screen.id):left",
                        upperBoundary: upper == frame.maxX ? "window:\(window.id):right" : "screen:\(screen.id):right")
                ]
                for cover in ordered where cover.zIndex < window.zIndex && isValid(cover.frame) {
                    // A front window hides this edge only when its interior crosses the top-edge y.
                    guard cover.frame.minY < top, cover.frame.maxY > top else { continue }
                    segments = segments.flatMap { segment in
                        subtract(segment, by: cover.frame.minX...cover.frame.maxX, coverID: cover.id)
                    }
                    if segments.isEmpty { break }
                }
                visible += segments.map { (screen.id, $0) }
            }
            for (_, segment) in visible {
                result.append(
                    Surface(
                        id: SurfaceID(
                            "window:\(window.id):top:\(segment.lowerBoundary):\(segment.upperBoundary)"),
                        kind: .windowTop, y: frame.maxY, minX: segment.lower, maxX: segment.upper))
            }
            result.append(contentsOf: visibleSides(of: window, ordered: ordered, screens: screens))
        }
        return result
    }

    private static func visibleSides(
        of window: TrackedWindow, ordered: [TrackedWindow], screens: [ScreenDescriptor]
    ) -> [Surface] {
        var result: [Surface] = []
        for screen in screens where isValid(screen.frame) && isValid(screen.visibleFrame) {
            let lower = max(window.frame.minY, screen.frame.minY)
            let usableTop = min(screen.frame.maxY, screen.visibleFrame.maxY)
            let upper = min(window.frame.maxY, usableTop)
            guard upper > lower else { continue }
            for (side, x, kind, windowBottom, windowTop) in [
                (
                    "left", window.frame.minX, SurfaceKind.windowLeft, "window:\(window.id):bottom",
                    "window:\(window.id):top"
                ),
                (
                    "right", window.frame.maxX, SurfaceKind.windowRight, "window:\(window.id):bottom",
                    "window:\(window.id):top"
                ),
            ] {
                guard x >= screen.frame.minX, x <= screen.frame.maxX else { continue }
                var segments = [
                    VisibleSegment(
                        lower: lower, upper: upper,
                        lowerBoundary: lower == window.frame.minY
                            ? "window:\(window.id):bottom" : "screen:\(screen.id):bottom",
                        upperBoundary: upper == window.frame.maxY
                            ? "window:\(window.id):top" : "screen:\(screen.id):top")
                ]
                for cover in ordered where cover.zIndex < window.zIndex && isValid(cover.frame) {
                    guard cover.frame.minX < x, cover.frame.maxX > x else { continue }
                    segments = segments.flatMap { segment in
                        subtractVertical(segment, by: cover.frame.minY...cover.frame.maxY, coverID: cover.id)
                    }
                    if segments.isEmpty { break }
                }
                for segment in segments where segment.upper > segment.lower {
                    let lowerBoundary = segment.lower == window.frame.minY ? windowBottom : segment.lowerBoundary
                    let upperBoundary = segment.upper == window.frame.maxY ? windowTop : segment.upperBoundary
                    result.append(
                        Surface(
                            id: SurfaceID("window:\(window.id):\(side):\(lowerBoundary):\(upperBoundary)"),
                            kind: kind, x: x, minY: segment.lower, maxY: segment.upper))
                }
            }
        }
        return result
    }

    private static func subtract(
        _ source: VisibleSegment, by cover: ClosedRange<CGFloat>, coverID: UInt32
    ) -> [VisibleSegment] {
        guard cover.upperBound > source.lower, cover.lowerBound < source.upper else { return [source] }
        var result: [VisibleSegment] = []
        if cover.lowerBound > source.lower {
            let upper = min(source.upper, cover.lowerBound)
            if upper > source.lower {
                result.append(
                    VisibleSegment(
                        lower: source.lower, upper: upper,
                        lowerBoundary: source.lowerBoundary, upperBoundary: "cover:\(coverID):left"))
            }
        }
        if cover.upperBound < source.upper {
            let lower = max(source.lower, cover.upperBound)
            if source.upper > lower {
                result.append(
                    VisibleSegment(
                        lower: lower, upper: source.upper,
                        lowerBoundary: "cover:\(coverID):right", upperBoundary: source.upperBoundary))
            }
        }
        return result
    }

    private static func subtractVertical(
        _ source: VisibleSegment, by cover: ClosedRange<CGFloat>, coverID: UInt32
    ) -> [VisibleSegment] {
        guard cover.upperBound > source.lower, cover.lowerBound < source.upper else { return [source] }
        var result: [VisibleSegment] = []
        if cover.lowerBound > source.lower {
            let upper = min(source.upper, cover.lowerBound)
            if upper > source.lower {
                result.append(
                    VisibleSegment(
                        lower: source.lower, upper: upper,
                        lowerBoundary: source.lowerBoundary, upperBoundary: "cover:\(coverID):bottom"))
            }
        }
        if cover.upperBound < source.upper {
            let lower = max(source.lower, cover.upperBound)
            if source.upper > lower {
                result.append(
                    VisibleSegment(
                        lower: lower, upper: source.upper,
                        lowerBoundary: "cover:\(coverID):top", upperBoundary: source.upperBoundary))
            }
        }
        return result
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
