import AppKit
import PetScapeCore
import QuartzCore
import Testing

@testable import PetScapeRendering

/// T5.4: `PetLayer`/`PetRenderer` configured from snapshots, without a window (testing.md).
@Suite("PetLayer and PetRenderer")
struct PetLayerTests {
    static func state(
        id: Int = 1, x: CGFloat = 1100, mirrored: Bool = false, frameIndex: Int = 0, size: CGFloat = 96,
        isVisible: Bool = true
    ) -> PetRenderState {
        PetRenderState(
            id: PetID(id), characterID: CharacterID("cat"), position: CGPoint(x: x, y: 0),
            size: CGSize(width: size, height: size),
            frame: AnimationFrameRef(
                clip: "walk", frameIndex: frameIndex, mirrored: mirrored, anchor: .init(x: 0.5, y: 0.074)),
            isVisible: isVisible)
    }

    /// A secondary screen to the right of the primary: overlay-local x = global x − 1000.
    static let screen = ScreenDescriptor(
        id: ScreenID(2), frame: CGRect(x: 1000, y: 0, width: 800, height: 600),
        visibleFrame: CGRect(x: 1000, y: 0, width: 800, height: 600), backingScale: 2, isPrimary: false)
    static let primary = ScreenDescriptor(
        id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1000, height: 600),
        visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 600), backingScale: 2, isPrimary: true)

    @Test func layerTakesBoundsAnchorPositionAndContentsFromTheSnapshot() throws {
        let image = try TestImages.opaque(width: 288, height: 288)
        let petLayer = PetLayer()
        petLayer.apply(Self.state(), overlayPosition: CGPoint(x: 100, y: 0), image: image)
        let layer = petLayer.layer
        #expect(layer.bounds == CGRect(x: 0, y: 0, width: 96, height: 96))  // displaySize, not 288 px
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.074))
        #expect(layer.position == CGPoint(x: 100, y: 0))
        #expect((layer.contents as AnyObject?) === image)
        #expect(layer.contentsGravity == .resize)
        #expect(layer.affineTransform() == .identity)
        #expect(!layer.isHidden)
    }

    @Test func mirroringFlipsAroundTheAnchorAndKeepsTheContactPoint() {
        let petLayer = PetLayer()
        petLayer.apply(Self.state(mirrored: true), overlayPosition: CGPoint(x: 100, y: 0), image: nil)
        #expect(petLayer.layer.affineTransform() == CGAffineTransform(scaleX: -1, y: 1))
        // Anchor stays at the contact point: the frame is symmetric around x = 100.
        #expect(petLayer.layer.frame == CGRect(x: 52, y: -96 * 0.074, width: 96, height: 96))
        petLayer.apply(Self.state(mirrored: false), overlayPosition: CGPoint(x: 100, y: 0), image: nil)
        #expect(petLayer.layer.affineTransform() == .identity)
    }

    @Test func climbAlignmentKeepsThePawAnchorAtEitherScreenEdge() {
        let layer = PetLayer()
        let climb = PetRenderState(
            id: PetID(2), characterID: CharacterID("cat"), position: CGPoint(x: 900, y: 400),
            size: CGSize(width: 96, height: 96),
            frame: AnimationFrameRef(
                clip: "climb", frameIndex: 0, mirrored: false, anchor: .init(x: 0.977, y: 0.5),
                alignment: .right), isVisible: true)
        layer.apply(climb, overlayPosition: CGPoint(x: 900, y: 400), image: nil)
        #expect(layer.layer.anchorPoint == CGPoint(x: 0.977, y: 0.5))
        #expect(layer.layer.position == CGPoint(x: 900, y: 400))
        #expect(layer.layer.affineTransform() == .identity)

        var mirrored = climb
        mirrored.position.x = 0
        mirrored.frame.mirrored = true
        layer.apply(mirrored, overlayPosition: .zero, image: nil)
        #expect(layer.layer.anchorPoint == CGPoint(x: 0.977, y: 0.5))
        #expect(layer.layer.affineTransform() == CGAffineTransform(scaleX: -1, y: 1))
        #expect(layer.layer.position == .zero)
    }

    @Test func implicitAnimationsAreDisabled() {
        let layer = PetLayer().layer
        for key in ["contents", "bounds", "position", "transform", "anchorPoint", "hidden"] {
            #expect(layer.actions?[key] is NSNull, "\(key)")
        }
    }

    @Test func invisiblePetsAreHidden() {
        let petLayer = PetLayer()
        petLayer.apply(Self.state(isVisible: false), overlayPosition: .zero, image: nil)
        #expect(petLayer.layer.isHidden)
    }

    @Test func rendererConvertsGlobalToOverlayLocalAndKeysLayersByPet() throws {
        let host = CALayer()
        let renderer = PetRenderer(hostLayer: host)
        let converter = try #require(CoordinateConverter(screens: [Self.primary, Self.screen]))
        let image = try TestImages.opaque(width: 8, height: 8)
        var requested: [Int] = []
        let snapshot = RenderSnapshot(pets: [Self.state(id: 1, x: 1100), Self.state(id: 2, x: 1500, frameIndex: 3)])
        renderer.render(snapshot, converter: converter, screen: Self.screen) { pet in
            requested.append(pet.frame.frameIndex)
            return image
        }
        #expect(host.sublayers?.count == 2)
        #expect(renderer.layer(for: PetID(1))?.layer.position == CGPoint(x: 100, y: 0))
        #expect(renderer.layer(for: PetID(2))?.layer.position == CGPoint(x: 500, y: 0))
        #expect(requested == [0, 3])

        // Same pet keeps its layer; a pet that disappears loses it.
        let first = renderer.layer(for: PetID(1))
        renderer.render(RenderSnapshot(pets: [Self.state(id: 1, x: 1200)]), converter: converter, screen: Self.screen) {
            _ in image
        }
        #expect(renderer.layer(for: PetID(1)) === first)
        #expect(renderer.layer(for: PetID(2)) == nil)
        #expect(host.sublayers?.count == 1)
        #expect(first?.layer.position == CGPoint(x: 200, y: 0))

        renderer.removeAll()
        #expect(host.sublayers?.isEmpty ?? true)
    }
}
