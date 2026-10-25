import CoreGraphics
import PetScapeCore
import PetScapePlatform
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("InteractionController")
@MainActor
struct InteractionControllerTests {
    @Test func primaryClickSubmitsOnlyForSamePetAndClearsCapture() {
        let petID = PetID(3)
        var commands: [InteractionCommand] = []
        var captures: [InteractionID?] = []
        let controller = InteractionController(
            hitTest: { _ in petID }, footPosition: { _ in CGPoint(x: 4, y: 5) },
            submit: { _, command in
                commands.append(command); return true
            },
            setCapture: { captures.append($0) })
        controller.handle(OverlayMouseEvent(kind: .down, location: .zero, timestamp: 1))
        controller.handle(OverlayMouseEvent(kind: .up, location: .zero, timestamp: 1.1))
        #expect(commands.count == 2)
        #expect(commands[0] == .press(InteractionID(1)))
        #expect(commands[1] == .click)
        #expect(captures == [InteractionID(1), nil])
        #expect(controller.phase == .idle)
    }

    @Test func dragAndLostPrimaryUpReleaseExactlyOnce() {
        let petID = PetID(3)
        var commands: [InteractionCommand] = []
        var captures: [InteractionID?] = []
        let controller = InteractionController(
            hitTest: { _ in petID }, footPosition: { _ in .zero },
            submit: { _, command in
                commands.append(command); return true
            },
            setCapture: { captures.append($0) })
        controller.handle(OverlayMouseEvent(kind: .down, location: .zero, timestamp: 1))
        controller.handle(OverlayMouseEvent(kind: .dragged, location: CGPoint(x: 4, y: 0), timestamp: 1.1))
        controller.update(
            with: CursorSample(
                location: CGPoint(x: 10, y: 0), isButtonDown: true, timestamp: 1.2,
                isPrimaryButtonDown: false))
        #expect(
            commands == [
                .press(InteractionID(1)),
                .beginHold(InteractionID(1), target: CGPoint(x: 4, y: 0)),
                .release(InteractionID(1), target: CGPoint(x: 10, y: 0)),
            ])
        #expect(captures == [InteractionID(1), nil])
        #expect(controller.phase == .idle)
    }

    @Test func secondaryDownAndRejectedPressNeverAcquireCapture() {
        let petID = PetID(3)
        var captureCount = 0
        let controller = InteractionController(
            hitTest: { _ in petID }, footPosition: { _ in .zero },
            submit: { _, _ in false }, setCapture: { _ in captureCount += 1 })
        controller.handle(
            OverlayMouseEvent(kind: .down, location: .zero, timestamp: 1, button: .secondary))
        #expect(controller.phase == .idle)
        controller.handle(OverlayMouseEvent(kind: .down, location: .zero, timestamp: 2))
        #expect(controller.phase == .idle)
        #expect(captureCount == 0)
    }

    @Test func targetedRemovalCancellationReleasesOnlyTheOwningPetCapture() {
        let owner = PetID(3)
        let other = PetID(8)
        var submitted: [(PetID, InteractionCommand)] = []
        var captures: [InteractionID?] = []
        let controller = InteractionController(
            hitTest: { _ in owner }, footPosition: { _ in .zero },
            submit: { id, command in
                submitted.append((id, command)); return true
            },
            setCapture: { captures.append($0) })

        controller.handle(OverlayMouseEvent(kind: .down, location: .zero, timestamp: 1))
        controller.handle(OverlayMouseEvent(kind: .dragged, location: CGPoint(x: 8, y: 0), timestamp: 1.1))
        controller.cancel(.petUnavailable, for: other)
        #expect(controller.phase == .dragging(petID: owner, id: InteractionID(1)))
        #expect(captures == [InteractionID(1)])

        controller.cancel(.petUnavailable, for: owner)
        #expect(controller.phase == .idle)
        #expect(submitted.last?.0 == owner)
        #expect(submitted.last?.1 == .cancel(InteractionID(1), reason: .petUnavailable))
        #expect(captures == [InteractionID(1), nil])
    }
}
