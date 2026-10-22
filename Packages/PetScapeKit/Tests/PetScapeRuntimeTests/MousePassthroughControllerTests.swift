import CoreGraphics
import Foundation
import Testing

@testable import PetScapePlatform
@testable import PetScapeRuntime

/// Pass-through state machine with a fake hit tester (T3.6, testing.md "Pass-through").
@Suite("MousePassthroughController")
struct MousePassthroughControllerTests {
    final class FakeHitTester: PetHitTesting {
        var petRect = CGRect(x: 100, y: 0, width: 96, height: 96)
        func containsPet(at globalPoint: CGPoint) -> Bool { petRect.contains(globalPoint) }
    }

    static let onPet = CGPoint(x: 140, y: 40)
    static let offPet = CGPoint(x: 400, y: 40)

    /// Controller plus the list of `ignoresMouseEvents` values it applied.
    final class Harness {
        let hitTester = FakeHitTester()
        var applied: [Bool] = []
        var time: TimeInterval = 0
        private(set) lazy var controller = MousePassthroughController(
            hitTester: hitTester, uptime: { [unowned self] in time },
            applyIgnoresMouseEvents: { [unowned self] in applied.append($0) })

        func move(_ point: CGPoint, button: Bool = false) {
            time += 1.0 / 60
            controller.update(with: CursorSample(location: point, isButtonDown: button, timestamp: time))
        }
    }

    @Test func startsPassingThrough() {
        let h = Harness()
        #expect(h.controller.state == .passThrough)
        #expect(!h.controller.isInteractive)
    }

    @Test func disabledDirectInteractionAlwaysPassesThrough() {
        let h = Harness()
        h.controller.isEnabled = false
        h.move(Self.onPet)
        h.controller.mouseDown(at: Self.onPet)
        #expect(h.controller.state == .passThrough)
        #expect(h.applied.isEmpty)
        h.controller.isEnabled = true
        h.move(Self.onPet)
        #expect(h.controller.state == .interactive)
        #expect(h.applied == [false])
    }

    @Test func enterAndLeaveTogglesOncePerCrossing() {
        let h = Harness()
        h.move(Self.offPet)
        h.move(Self.onPet)
        h.move(CGPoint(x: 150, y: 50))  // still on the pet: no new toggle
        h.move(Self.offPet)
        h.move(Self.offPet)
        #expect(h.applied == [false, true])
        #expect(h.controller.state == .passThrough)
    }

    @Test func toggleHappensOnTheFirstSampleOverThePet() {
        // ≤ 1 frame latency by construction (AC-M3-04): the sample that sees the pet applies the change.
        let h = Harness()
        h.move(Self.offPet)
        #expect(h.applied.isEmpty)
        h.move(Self.onPet)
        #expect(h.applied == [false])
    }

    @Test func dragKeepsInteractivityUntilMouseUp() {
        let h = Harness()
        h.move(Self.onPet)
        h.controller.mouseDown(at: Self.onPet)
        #expect(h.controller.state == .dragging)

        // The cursor leaves the pet mid-drag (PoC E4): still interactive.
        h.move(Self.offPet, button: true)
        h.move(CGPoint(x: 700, y: 0), button: true)
        #expect(h.controller.state == .dragging)
        #expect(h.applied == [false])

        h.controller.mouseUp(at: CGPoint(x: 700, y: 0))
        #expect(h.controller.state == .passThrough)
        #expect(h.applied == [false, true])
    }

    @Test func mouseUpOverThePetStaysInteractive() {
        let h = Harness()
        h.move(Self.onPet)
        h.controller.mouseDown(at: Self.onPet)
        h.controller.mouseUp(at: Self.onPet)
        #expect(h.controller.state == .interactive)
        #expect(h.applied == [false])
    }

    @Test func lostMouseUpIsRecoveredFromTheButtonState() {
        let h = Harness()
        h.move(Self.onPet)
        h.controller.mouseDown(at: Self.onPet)
        h.move(Self.offPet, button: false)  // mouse-up never delivered
        #expect(h.controller.state == .passThrough)
        #expect(h.applied == [false, true])
    }

    @Test func dragsFromOtherAppsPassingOverThePetAreNotCaptured() {
        let h = Harness()
        h.move(Self.offPet, button: true)
        h.move(Self.onPet, button: true)  // e.g. a file dragged from Finder to the Dock
        #expect(h.controller.state == .passThrough)
        h.move(Self.onPet, button: false)  // dropped elsewhere, cursor rests on the pet
        #expect(h.controller.state == .interactive)
    }

    @Test func mouseEventsOutsideTheirStateAreIgnored() {
        let h = Harness()
        h.controller.mouseDown(at: Self.onPet)  // not interactive yet
        h.controller.mouseUp(at: Self.onPet)
        #expect(h.controller.state == .passThrough)
        #expect(h.applied.isEmpty)
    }

    @Test func resetReturnsToPassThroughFromAnyState() {
        let h = Harness()
        h.move(Self.onPet)
        h.controller.mouseDown(at: Self.onPet)
        h.controller.reset()
        #expect(h.controller.state == .passThrough)
        #expect(h.applied == [false, true])
        h.controller.reset()
        #expect(h.applied == [false, true])
    }

    @Test func movingPetIsFollowed() {
        let h = Harness()
        h.move(Self.onPet)
        h.hitTester.petRect.origin.x = 300  // the pet walked away from the resting cursor
        h.move(Self.onPet)
        #expect(h.controller.state == .passThrough)
    }

    @Test func hitTesterCanBeReplaced() {
        let h = Harness()
        let empty = FakeHitTester()
        empty.petRect = .null
        h.controller.hitTester = empty
        h.move(Self.onPet)
        #expect(h.controller.state == .passThrough)
        let wide = FakeHitTester()
        wide.petRect = CGRect(x: 0, y: 0, width: 1000, height: 100)
        h.controller.hitTester = wide
        h.move(Self.offPet)
        #expect(h.controller.state == .interactive)
    }
}
