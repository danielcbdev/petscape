import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Swept landing")
struct LandingTests {
    static let range: ClosedRange<CGFloat> = -10000...10000
    static func geometry(_ width: CGFloat = 96) throws -> ContactGeometry {
        try #require(ContactGeometry(displaySize: CGSize(width: width, height: 96), scale: 1))
    }
    static func shelf(
        _ id: String, y: CGFloat = 0, x: ClosedRange<CGFloat> = -500...500,
        kind: SurfaceKind = .screenBottom
    ) -> Surface {
        Surface(id: SurfaceID(id), kind: kind, y: y, minX: x.lowerBound, maxX: x.upperBound)
    }
    @Test func usesXAtImpact() throws {
        let map = SurfaceMap([Self.shelf("floor", x: 5...15)])
        let hit = try #require(
            map.firstLanding(
                from: CGPoint(x: 0, y: 10), to: CGPoint(x: 20, y: -10),
                geometry: Self.geometry(4), visualRange: Self.range, tolerance: 1e-6))
        #expect(hit.position == CGPoint(x: 10, y: 0))
        #expect(hit.fraction == 0.5)
    }
    @Test func firstHitWins() throws {
        let map = SurfaceMap([Self.shelf("floor"), Self.shelf("dock", y: 20)])
        #expect(
            map.firstLanding(
                from: CGPoint(x: 0, y: 30), to: CGPoint(x: 0, y: -30),
                geometry: try Self.geometry(), visualRange: Self.range, tolerance: 1e-6)?.surfaceID == SurfaceID("dock")
        )
    }
    @Test func tieIndependentOfInsertionOrder() throws {
        let a = Self.shelf("a", kind: .dockTop)
        let b = Self.shelf("b", kind: .dockTop)
        let floor = Self.shelf("0-floor")
        for surfaces in [[a, b, floor], [floor, b, a], [b, a, floor]] {
            #expect(
                SurfaceMap(surfaces).firstLanding(
                    from: CGPoint(x: 0, y: 1), to: CGPoint(x: 0, y: -1),
                    geometry: try Self.geometry(), visualRange: Self.range, tolerance: 1e-6)?.surfaceID == a.id)
        }
    }
    @Test func nearEqualHeightChainIsOrderIndependent() throws {
        let a = Self.shelf("a", y: 0)
        let b = Self.shelf("b", y: 0.75e-6)
        let c = Self.shelf("c", y: 1.5e-6)
        for surfaces in [[a, b, c], [c, b, a], [b, c, a], [a, c, b], [b, a, c], [c, a, b]] {
            #expect(
                SurfaceMap(surfaces).firstLanding(
                    from: CGPoint(x: 0, y: 1), to: CGPoint(x: 0, y: -1),
                    geometry: try Self.geometry(), visualRange: Self.range, tolerance: 1e-6)?.surfaceID == b.id)
        }
    }
    @Test func ascendingPassesThrough() throws {
        let map = SurfaceMap([Self.shelf("shelf")])
        for pair in [(CGFloat(-10), CGFloat(10)), (-10, -20), (0, 0)] {
            #expect(
                map.firstLanding(
                    from: CGPoint(x: 0, y: pair.0), to: CGPoint(x: 0, y: pair.1),
                    geometry: try Self.geometry(), visualRange: Self.range, tolerance: 1e-6) == nil)
        }
    }
    @Test func narrowSurfaceRejected() throws {
        #expect(
            SurfaceMap([Self.shelf("narrow", x: -10...10)]).firstLanding(
                from: CGPoint(x: 0, y: 10), to: CGPoint(x: 0, y: -10), geometry: try Self.geometry(),
                visualRange: Self.range, tolerance: 1e-6) == nil)
    }
    @Test func exactBoundaryContact() throws {
        let map = SurfaceMap([Self.shelf("shelf", x: 0...100)])
        let hit = map.firstLanding(
            from: CGPoint(x: 24, y: 0), to: CGPoint(x: 24, y: -30),
            geometry: try Self.geometry(), visualRange: 24...76, tolerance: 1e-6)
        #expect(hit?.position == CGPoint(x: 24, y: 0))
        #expect(hit?.fraction == 0)
    }
    @Test func nonfiniteSurfaceIgnored() throws {
        let map = SurfaceMap([Self.shelf("invalid", y: .nan), Self.shelf("floor")])
        #expect(
            map.firstLanding(
                from: CGPoint(x: 0, y: 1), to: CGPoint(x: 0, y: -1),
                geometry: try Self.geometry(), visualRange: Self.range, tolerance: 1e-6)?.surfaceID
                == SurfaceID("floor"))
    }
    @Test func terminalDropsNeverTunnel() throws {
        var random = SeededRandomSource(seed: 701)
        let geometry = try Self.geometry()
        for _ in 0..<10000 {
            let y = CGFloat(Int(random.next() % 10000) - 5000)
            let offset = CGFloat(random.next() % 30000) / 1000
            let map = SurfaceMap([Self.shelf("floor", y: y)])
            let hit = map.firstLanding(
                from: CGPoint(x: 0, y: y + offset), to: CGPoint(x: 0, y: y + offset - 30),
                geometry: geometry, visualRange: Self.range, tolerance: 1e-6)
            #expect(hit?.position.y == y)
        }
    }
}
