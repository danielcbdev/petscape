import CoreGraphics
import Testing

@testable import PetScapeRendering

@Suite("Overlay mouse event")
struct OverlayMouseEventTests {
    @Test func constructorPreservesLocationTimeAndButtonIdentity() {
        let event = OverlayMouseEvent(
            kind: .down, location: CGPoint(x: -1920, y: 30), timestamp: 42, button: .other(3))
        #expect(event.kind == .down)
        #expect(event.location == CGPoint(x: -1920, y: 30))
        #expect(event.timestamp == 42)
        #expect(event.button == .other(3))
    }

    @Test func existingCallSitesDefaultToPrimaryButton() {
        let event = OverlayMouseEvent(kind: .up, location: .zero, timestamp: 3)
        #expect(event.button == .primary)
    }
}
