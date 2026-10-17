import CoreGraphics
import PetScapeCore
import Testing

@testable import PetScapeRendering

/// T5.8: global point → pet via the frame's alpha mask, with mirroring and scale.
@Suite("PetHitTester")
struct PetHitTesterTests {
    /// 288 px frame whose only opaque area is a "left paw": the left third of the bottom third.
    static func pawMask() throws -> HitMask {
        let image = try TestImages.make(width: 288, height: 288) { x, y in x < 96 && y >= 192 ? 255 : 0 }
        return try #require(HitMask(image: image))
    }

    /// Contact point (500, 100), anchor at the bottom center: sprite rect x 452…548, y 100…196 at 96 pt
    /// (3 px per point, so the paw covers x 452…484, y 100…132).
    static func snapshot(mirrored: Bool = false, size: CGFloat = 96, id: Int = 1, x: CGFloat = 500) -> RenderSnapshot {
        RenderSnapshot(pets: [
            PetRenderState(
                id: PetID(id), characterID: CharacterID("cat"), position: CGPoint(x: x, y: 100),
                size: CGSize(width: size, height: size),
                frame: AnimationFrameRef(clip: "walk", frameIndex: 0, mirrored: mirrored, anchor: .init(x: 0.5, y: 0)),
                isVisible: true)
        ])
    }

    @Test func hitsOnlyOpaquePixels() throws {
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        tester.update(Self.snapshot()) { _ in mask }
        #expect(tester.petID(at: CGPoint(x: 460, y: 110)) == PetID(1))
        #expect(!tester.containsPet(at: CGPoint(x: 520, y: 110)))  // inside the rect, transparent
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 180)))
    }

    @Test func pointsFivePointsOutsideTheSilhouettePassThrough() throws {
        // AC-M5-02: the mask is dilated by one cell (4 px ≈ 1.3 pt at 96 pt), never by 5 pt.
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        tester.update(Self.snapshot()) { _ in mask }
        #expect(tester.containsPet(at: CGPoint(x: 483, y: 110)))
        #expect(!tester.containsPet(at: CGPoint(x: 484 + 5, y: 110)))  // right of the paw
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 132 + 5)))  // above the paw
        #expect(!tester.containsPet(at: CGPoint(x: 452 - 5, y: 110)))  // left of the sprite
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 100 - 5)))  // below the contact line
    }

    @Test func mirroredPetsAreHitOnTheMirroredSide() throws {
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        tester.update(Self.snapshot(mirrored: true)) { _ in mask }
        #expect(tester.containsPet(at: CGPoint(x: 540, y: 110)))
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 110)))
    }

    @Test func scaleChangesTheCoveredArea() throws {
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        tester.update(Self.snapshot(size: 144)) { _ in mask }  // rect 428…572, paw 428…476
        #expect(tester.containsPet(at: CGPoint(x: 470, y: 140)))
        #expect(!tester.containsPet(at: CGPoint(x: 485, y: 110)))
    }

    @Test func invisiblePetsAndPetsWithoutMasksAreNotHit() throws {
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        var hidden = Self.snapshot()
        hidden.pets[0].isVisible = false
        tester.update(hidden) { _ in mask }
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 110)))
        tester.update(Self.snapshot()) { _ in nil }
        #expect(!tester.containsPet(at: CGPoint(x: 460, y: 110)))
    }

    @Test func theTopmostPetWins() throws {
        let mask = try Self.pawMask()
        let tester = PetHitTester()
        var both = Self.snapshot(id: 1)
        both.pets += Self.snapshot(id: 2).pets
        tester.update(both) { _ in mask }
        #expect(tester.petID(at: CGPoint(x: 460, y: 110)) == PetID(2))
        tester.removeAll()
        #expect(tester.petID(at: CGPoint(x: 460, y: 110)) == nil)
    }
}
