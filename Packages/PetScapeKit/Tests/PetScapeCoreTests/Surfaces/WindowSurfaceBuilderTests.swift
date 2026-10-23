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
            .filter { $0.kind == .windowTop }
        #expect(
            surfaces.map { $0.id.rawValue } == [
                "window:11:top:window:11:left:window:11:right",
                "window:10:top:screen:1:left:cover:11:left",
                "window:10:top:cover:11:right:window:10:right",
            ])
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
        #expect(WindowSurfaceBuilder.build(windows: windows, screens: [screen]).allSatisfy { $0.isVertical })
    }

    @Test func coveringAWindowChangesItsSegmentIdentitySoAttachmentIsRemoved() {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 500, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 500, height: 480), backingScale: 1, isPrimary: true)
        let back = TrackedWindow(id: 10, ownerPID: 1, frame: CGRect(x: 0, y: 20, width: 400, height: 40), zIndex: 1)
        let front = TrackedWindow(id: 11, ownerPID: 2, frame: CGRect(x: 150, y: 50, width: 100, height: 50), zIndex: 0)
        let uncovered = WindowSurfaceBuilder.build(windows: [back], screens: [screen]).filter { $0.kind == .windowTop }
        let covered = WindowSurfaceBuilder.build(windows: [front, back], screens: [screen]).filter {
            $0.kind == .windowTop
        }
        let oldBackIDs = Set(uncovered.filter { $0.id.rawValue.hasPrefix("window:10:") }.map(\.id))
        let newBackIDs = Set(covered.filter { $0.id.rawValue.hasPrefix("window:10:") }.map(\.id))
        #expect(oldBackIDs.count == 1)
        #expect(newBackIDs.count == 2)
        #expect(oldBackIDs.isDisjoint(with: newBackIDs))
    }

    @Test func windowMoveAndResizeKeepVisibleSegmentIdentity() {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 780), backingScale: 1, isPrimary: true)
        let original = TrackedWindow(
            id: 12, ownerPID: 1, frame: CGRect(x: 100, y: 100, width: 500, height: 200), zIndex: 0)
        let moved = TrackedWindow(
            id: 12, ownerPID: 1, frame: CGRect(x: 150, y: 120, width: 500, height: 200), zIndex: 0)
        let resized = TrackedWindow(
            id: 12, ownerPID: 1, frame: CGRect(x: 150, y: 120, width: 600, height: 240), zIndex: 0)
        let originalIDs = WindowSurfaceBuilder.build(windows: [original], screens: [screen]).map(\.id)
        #expect(WindowSurfaceBuilder.build(windows: [moved], screens: [screen]).map(\.id) == originalIDs)
        #expect(WindowSurfaceBuilder.build(windows: [resized], screens: [screen]).map(\.id) == originalIDs)
    }

    @Test func windowSidesAreVisibleVerticalSurfacesAndRespectFrontWindowOcclusion() {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 500, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 500, height: 480), backingScale: 1, isPrimary: true)
        let back = TrackedWindow(id: 10, ownerPID: 1, frame: CGRect(x: 100, y: 50, width: 300, height: 300), zIndex: 1)
        let front = TrackedWindow(id: 11, ownerPID: 2, frame: CGRect(x: 99, y: 120, width: 100, height: 80), zIndex: 0)

        let surfaces = WindowSurfaceBuilder.build(windows: [back, front], screens: [screen])
        let leftSegments = surfaces.filter { $0.id.rawValue.hasPrefix("window:10:left:") }
        let rightSegments = surfaces.filter { $0.id.rawValue.hasPrefix("window:10:right:") }

        #expect(leftSegments.count == 2)
        #expect(leftSegments.map(\.minY) == [50, 200])
        #expect(leftSegments.map(\.maxY) == [120, 350])
        #expect(rightSegments.count == 1)
        #expect(rightSegments[0].minY == 50 && rightSegments[0].maxY == 350)
        #expect(leftSegments.allSatisfy { $0.isVertical && $0.kind == .windowLeft })
    }
}
