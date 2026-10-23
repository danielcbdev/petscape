import CoreGraphics
import PetScapeCore
import Testing

struct WindowSurfaceBuilderTests {
    @Test func correlatesByProcessAndFrameAndRejectsAmbiguity() {
        let target = CGRect(x: 20, y: 30, width: 200, height: 100)
        let windows = [
            TrackedWindow(id: 10, ownerPID: 4, frame: target.offsetBy(dx: 1, dy: 0), zIndex: 0),
            TrackedWindow(id: 11, ownerPID: 4, frame: target.offsetBy(dx: -1, dy: 0), zIndex: 1),
            TrackedWindow(id: 12, ownerPID: 9, frame: target, zIndex: 2),
        ]
        #expect(WindowFrameCorrelator.match(ownerPID: 4, frame: target, windows: windows, tolerance: 2) == .ambiguous)
        #expect(
            WindowFrameCorrelator.match(ownerPID: 4, frame: target, windows: [windows[0]], tolerance: 2) == .matched(10)
        )
        #expect(
            WindowFrameCorrelator.match(ownerPID: 4, frame: target, windows: [windows[0]], tolerance: 0.5) == .noMatch)
    }

    @Test func subtractsFrontWindowAndClipsToScreen() {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 90), backingScale: 2, isPrimary: true)
        let back = TrackedWindow(id: 10, ownerPID: 1, frame: CGRect(x: -20, y: 20, width: 120, height: 40), zIndex: 2)
        let front = TrackedWindow(id: 11, ownerPID: 2, frame: CGRect(x: 30, y: 40, width: 30, height: 40), zIndex: 1)
        let surfaces = WindowSurfaceBuilder.build(windows: [back, front], screens: [screen])
        #expect(surfaces.map { $0.id.rawValue } == ["window:11:top:0", "window:10:top:0", "window:10:top:1"])
        #expect(surfaces[1].minX == 0 && surfaces[1].maxX == 30)
        #expect(surfaces[2].minX == 60 && surfaces[2].maxX == 100)
        #expect(surfaces[0].y == 80)
    }

    @Test func excludesMenuBarAndInvalidOrMinimizedFrames() {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 90), backingScale: 1, isPrimary: true)
        let windows = [
            TrackedWindow(id: 1, ownerPID: 1, frame: CGRect(x: 0, y: 80, width: 50, height: 15), zIndex: 0),
            TrackedWindow(
                id: 2, ownerPID: 1, frame: CGRect(x: 0, y: 10, width: 50, height: 10), zIndex: 1, isMinimized: true),
            TrackedWindow(id: 3, ownerPID: 1, frame: CGRect(x: CGFloat.nan, y: 10, width: 50, height: 10), zIndex: 2),
        ]
        #expect(WindowSurfaceBuilder.build(windows: windows, screens: [screen]).isEmpty)
    }
}
