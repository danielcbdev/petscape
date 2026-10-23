import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

/// T5.1: horizontal surfaces, queries and diffs (surface-detection.md#tests).
@Suite("Surface and SurfaceMap")
struct SurfaceMapTests {
    static let floor = Surface(id: SurfaceID("floor"), kind: .screenBottom, y: 0, minX: 0, maxX: 1000)
    static let shelf = Surface(id: SurfaceID("shelf"), kind: .dockTop, y: 60, minX: 200, maxX: 800)

    @Test func endsAreNormalizedLeftToRight() {
        let surface = Surface(id: SurfaceID("s"), kind: .screenBottom, y: 5, minX: 300, maxX: 100)
        #expect(surface.minX == 100)
        #expect(surface.maxX == 300)
        #expect(surface.segment.start == CGPoint(x: 100, y: 5))
        #expect(surface.width == 200)
    }

    @Test func parameterAndPointAreInverse() {
        let surface = Self.shelf
        #expect(surface.point(atParameter: 0) == CGPoint(x: 200, y: 60))
        #expect(surface.point(atParameter: 1) == CGPoint(x: 800, y: 60))
        #expect(surface.parameter(atX: 350) == 0.25)
        #expect(surface.point(atParameter: surface.parameter(atX: 437)).x == 437)
    }

    @Test func walkableRangeKeepsTheMarginAndCollapsesOnNarrowSurfaces() {
        #expect(Self.floor.walkableRange(margin: 48) == 48...952)
        let narrow = Surface(id: SurfaceID("n"), kind: .screenBottom, y: 0, minX: 10, maxX: 60)
        #expect(narrow.walkableRange(margin: 48) == 35...35)
    }

    @Test func screenBottomSpansTheScreenAtItsBottomEdge() {
        let screen = ScreenDescriptor(
            id: ScreenID(7), frame: CGRect(x: -1440, y: -200, width: 1440, height: 900),
            visibleFrame: CGRect(x: -1440, y: -130, width: 1440, height: 800), backingScale: 2, isPrimary: false)
        let surface = Surface.screenBottom(of: screen)
        #expect(surface.id == SurfaceID("screen:7:bottom"))
        #expect(surface.kind == .screenBottom)
        #expect(surface.y == -200)
        #expect(surface.minX == -1440)
        #expect(surface.maxX == 0)
    }

    @Test func screenWallsUseCanonicalGlobalEdgesAndStableIDs() {
        let screen = ScreenDescriptor(
            id: ScreenID(9), frame: CGRect(x: -1280, y: -120, width: 1280, height: 800),
            visibleFrame: CGRect(x: -1280, y: -70, width: 1280, height: 750), backingScale: 2, isPrimary: false)
        let walls = SurfaceMap.screenWalls(for: [screen])
        #expect(walls.map(\.id) == [.screenLeft(of: screen.id), .screenRight(of: screen.id)])
        #expect(walls[0].kind == .screenLeft && walls[0].isVertical)
        #expect(walls[0].segment.start == CGPoint(x: -1280, y: -120))
        #expect(walls[0].segment.end == CGPoint(x: -1280, y: 680))
        #expect(walls[1].segment.start.x == 0 && walls[1].segment.end.x == 0)
        #expect(walls[1].minY == -120 && walls[1].maxY == 680)
    }

    @Test func wallDiffsPreserveIdentityWhenMovedAndRemoveCleanly() {
        var wall = Surface(id: .screenLeft(of: ScreenID(1)), kind: .screenLeft, x: -100, minY: -50, maxY: 850)
        var map = SurfaceMap([wall])
        wall = Surface(id: wall.id, kind: .screenLeft, x: -120, minY: -50, maxY: 950)
        #expect(map.changes(to: [wall]) == [.moved(wall)])
        map.apply(map.changes(to: [wall]))
        #expect(map.surface(wall.id) == wall)
        #expect(map.changes(to: []) == [.removed(wall.id)])
    }

    @Test func verticalParameterAndPointRoundTrip() {
        let wall = Surface(id: .screenRight(of: ScreenID(2)), kind: .screenRight, x: 100, minY: -100, maxY: 900)
        #expect(wall.point(atParameter: 0.25) == CGPoint(x: 100, y: 150))
        #expect(wall.parameter(atY: 300) == 0.4)
        #expect(wall.point(atParameter: wall.parameter(atY: 433)).y == 433)
    }

    @Test func lookupByID() {
        let map = SurfaceMap([Self.floor, Self.shelf])
        #expect(map.surface(SurfaceID("shelf")) == Self.shelf)
        #expect(map.surface(SurfaceID("missing")) == nil)
    }

    @Test func movedSurfaceKeepsItsID() {
        var map = SurfaceMap([Self.floor, Self.shelf])
        var resized = Self.shelf
        resized = Surface(id: resized.id, kind: .dockTop, y: 70, minX: 150, maxX: 850)
        let changes = map.changes(to: [Self.floor, resized])
        #expect(changes == [.moved(resized)])
        map.apply(changes)
        #expect(map.surfaces == [Self.floor, resized])
    }

    @Test func removedSurfaceEmitsARemoval() {
        var map = SurfaceMap([Self.floor, Self.shelf])
        let changes = map.changes(to: [Self.floor])
        #expect(changes == [.removed(SurfaceID("shelf"))])
        map.apply(changes)
        #expect(map.surface(SurfaceID("shelf")) == nil)
    }

    @Test func addedAndUnchangedSurfaces() {
        let map = SurfaceMap([Self.floor])
        #expect(map.changes(to: [Self.floor]).isEmpty)
        #expect(map.changes(to: [Self.floor, Self.shelf]) == [.added(Self.shelf)])
    }

    @Test func duplicateIDsKeepTheFirstOccurrence() {
        let other = Surface(id: SurfaceID("floor"), kind: .screenBottom, y: 99, minX: 0, maxX: 10)
        let map = SurfaceMap([Self.floor, other])
        #expect(map.surfaces == [Self.floor])
    }

    @Test func highestWalkableBelowAPoint() {
        let map = SurfaceMap([Self.floor, Self.shelf])
        #expect(map.highestWalkable(below: CGPoint(x: 500, y: 300))?.id == SurfaceID("shelf"))
        #expect(map.highestWalkable(below: CGPoint(x: 100, y: 300))?.id == SurfaceID("floor"))  // outside the shelf
        #expect(map.highestWalkable(below: CGPoint(x: 500, y: 30))?.id == SurfaceID("floor"))  // below the shelf
        #expect(map.highestWalkable(below: CGPoint(x: 500, y: -1)) == nil)
    }

    @Test func spawnSurfacePrefersTheDockTop() {
        #expect(SurfaceMap([Self.floor, Self.shelf]).spawnSurface?.id == SurfaceID("shelf"))
        #expect(SurfaceMap([Self.floor]).spawnSurface?.id == SurfaceID("floor"))
        #expect(SurfaceMap().spawnSurface == nil)
    }
}
