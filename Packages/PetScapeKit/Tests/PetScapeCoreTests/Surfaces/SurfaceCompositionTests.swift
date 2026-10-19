import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Persistent floors")
struct SurfaceCompositionTests {
    static let screen = ScreenDescriptor(
        id: ScreenID(1),
        frame: CGRect(x: -1440, y: -200, width: 1440, height: 900),
        visibleFrame: CGRect(x: -1440, y: -136, width: 1440, height: 800), backingScale: 2, isPrimary: true)
    @Test func floorsRespectNegativeCoordinates() {
        #expect(SurfaceMap.screenBottoms(for: [Self.screen]) == [Surface.screenBottom(of: Self.screen)])
    }
    @Test func noScreensProducesNoFloors() {
        #expect(SurfaceMap.screenBottoms(for: []).isEmpty)
    }
    @Test func duplicateScreenIDsDoNotDuplicateFloors() {
        #expect(SurfaceMap.screenBottoms(for: [Self.screen, Self.screen]).count == 1)
    }
    @Test func floorAndDockCoexistAndDockIsPreferredOnlyForSpawn() {
        let floor = Surface.screenBottom(of: Self.screen)
        let dock = Surface(id: .dock, kind: .dockTop, y: -136, minX: -1440, maxX: 0)
        let map = SurfaceMap([dock] + SurfaceMap.screenBottoms(for: [Self.screen]))
        #expect(map.surfaces.count == 2)
        #expect(map.spawnSurface?.id == .dock)
        #expect(map.surface(floor.id) == floor)
    }
}
