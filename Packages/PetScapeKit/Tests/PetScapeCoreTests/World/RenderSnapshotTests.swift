import CoreGraphics
import Testing

@testable import PetScapeCore

/// T5.4 (Core part): what a snapshot tells the renderer and the hit tester.
@Suite("RenderSnapshot")
struct RenderSnapshotTests {
    static func state(anchorX: Double, mirrored: Bool) -> PetRenderState {
        PetRenderState(
            id: PetID(1), characterID: CharacterID("cat"), position: CGPoint(x: 500, y: 70),
            size: CGSize(width: 96, height: 96),
            frame: AnimationFrameRef(
                clip: "walk", frameIndex: 0, mirrored: mirrored, anchor: .init(x: anchorX, y: 0.25)),
            isVisible: true)
    }

    @Test func spriteRectIsPlacedByTheAnchor() {
        #expect(Self.state(anchorX: 0.5, mirrored: false).spriteRect == CGRect(x: 452, y: 46, width: 96, height: 96))
        #expect(Self.state(anchorX: 0.25, mirrored: false).spriteRect == CGRect(x: 476, y: 46, width: 96, height: 96))
    }

    @Test func mirroringFlipsTheRectAroundTheAnchor() {
        #expect(Self.state(anchorX: 0.25, mirrored: true).spriteRect == CGRect(x: 428, y: 46, width: 96, height: 96))
        #expect(Self.state(anchorX: 0.5, mirrored: true).spriteRect == CGRect(x: 452, y: 46, width: 96, height: 96))
    }

    @Test func snapshotCarriesSizeFrameAndVisibility() throws {
        var world = PetWorld(random: SeededRandomSource(seed: 3))
        world.apply(.surfaces([Surface(id: SurfaceID("f"), kind: .screenBottom, y: 0, minX: 0, maxX: 800)]))
        world.spawn(try Fixtures.walkingDefinition(), scale: 1.5)
        var snapshot = RenderSnapshot()
        world.writeSnapshot(into: &snapshot)
        let pet = try #require(snapshot.pets.first)
        #expect(pet.size == CGSize(width: 144, height: 144))
        #expect(pet.characterID == CharacterID("walker"))
        #expect(pet.frame.clip == "walk")
        #expect(pet.isVisible)
        #expect(!snapshot.isAnimating)  // placed spawning pose is static until the first step
        #expect(world.needsSimulationSteps)
        world.writeSnapshot(into: &snapshot)  // reuses storage, same content
        #expect(snapshot.pets.count == 1)
        #expect(!RenderSnapshot().isAnimating)
    }

    @Test func seededSourceIsDeterministic() {
        var a = SeededRandomSource(seed: 9)
        var b = SeededRandomSource(seed: 9)
        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in b.next() })
        var c = SeededRandomSource(seed: 10)
        #expect(a.next() != c.next())
    }
}
