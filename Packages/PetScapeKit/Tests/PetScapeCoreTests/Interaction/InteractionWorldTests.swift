import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("Interaction authority in PetWorld")
struct InteractionWorldTests {
    private static let dt = 1.0 / 60

    @Test func pressReservationFreezesPetAndRestoresActivityDeadline() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let id = world.pets[0].id
        world.pets[0].activity = .walk
        world.pets[0].activityDeadline = 10
        let state = world.pets[0].state
        let elapsed = world.pets[0].stateElapsed
        let position = world.pets[0].position
        world.apply(.interaction(id, .press(InteractionID(1))))
        var events: [WorldEvent] = []
        world.drainEvents(into: &events)
        #expect(events.contains(.interactionAccepted(id, InteractionID(1))))
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == state)
        #expect(world.pets[0].stateElapsed == elapsed)
        #expect(world.pets[0].position == position)
        #expect(world.pets[0].activityDeadline == 10)

        world.apply(.interaction(id, .click))
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        // The click hold lasts one complete curious look (1.8 s): still reacting just before it ends.
        for _ in 0..<107 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        for _ in 0..<2 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == state)
        #expect(abs(world.pets[0].activityDeadline - (world.time + 10)) < Self.dt)
    }

    @Test func heldMotionIsWorldOwnedClampedAndReleaseFallsWithoutImpulse() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let id = world.pets[0].id
        world.apply(.interaction(id, .press(InteractionID(7))))
        world.apply(.interaction(id, .beginHold(InteractionID(7), target: CGPoint(x: 500, y: 300))))
        #expect(world.pets[0].state == .held)
        #expect(world.pets[0].heldPickupPresentationActive)
        #expect(world.pets[0].position == CGPoint(x: 500, y: 300))
        #expect(world.pets[0].velocity == .zero)
        #expect(world.snapshot().pets.first?.isVisible == true)

        for _ in 0..<12 { _ = world.step(dt: Self.dt) }
        #expect(!world.pets[0].heldPickupPresentationActive)

        world.apply(.interaction(id, .moveHold(InteractionID(7), target: CGPoint(x: 20_000, y: 20_000))))
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].position.x <= PetWorldTests.screen.frame.maxX)
        #expect(world.pets[0].position.y <= PetWorldTests.screen.frame.maxY)
        let releaseTarget = world.pets[0].position
        world.apply(.interaction(id, .release(InteractionID(7), target: releaseTarget)))
        #expect(world.pets[0].state == .airborne(.falling))
        #expect(world.pets[0].velocity == .zero)
        #expect(world.pets[0].attachment == nil)
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].position.y < releaseTarget.y)
    }

    @Test func staleOrNonFiniteSessionCommandsCannotMovePet() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let id = world.pets[0].id
        let position = world.pets[0].position
        world.apply(.interaction(id, .moveHold(InteractionID(9), target: CGPoint(x: 900, y: 400))))
        world.apply(.interaction(id, .press(InteractionID(0))))
        world.apply(.interaction(id, .press(InteractionID(8))))
        world.apply(.interaction(id, .beginHold(InteractionID(8), target: CGPoint(x: CGFloat.infinity, y: 400))))
        #expect(world.pets[0].position == position)
        #expect(world.pets[0].state == .walking)
    }

    @Test func awakeClickHasBoundedReactionAndRestoresWalking() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let petID = world.pets[0].id
        world.apply(.interaction(petID, .click))
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        // The click hold lasts one complete curious look (1.8 s): still reacting just before it ends.
        for _ in 0..<107 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        for _ in 0..<2 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .walking)

        world.apply(.interaction(petID, .click))
        #expect(world.pets[0].state == .walking)
    }

    @Test func reduceMotionKeepsClickTimingWithoutCuriousAnimation() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let petID = world.pets[0].id
        world.apply(.setReduceMotion(true))
        world.apply(.interaction(petID, .click))
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        #expect(world.pets[0].animation.requestedClip == "idle")
        // The click hold lasts one complete curious look (1.8 s): still reacting just before it ends.
        for _ in 0..<107 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .grounded(.reactingToClick))
        for _ in 0..<2 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .walking)
    }

    @Test func lifecycleCancellationCommitsLatestHeldTargetBeforeFalling() throws {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        let petID = world.pets[0].id
        let id = InteractionID(2)
        world.apply(.interaction(petID, .press(id)))
        world.apply(.interaction(petID, .beginHold(id, target: CGPoint(x: 500, y: 300))))
        world.apply(.interaction(petID, .moveHold(id, target: CGPoint(x: 550, y: 350))))
        world.apply(.interaction(petID, .cancel(id, reason: .paused)))
        #expect(world.pets[0].position == CGPoint(x: 550, y: 350))
        #expect(world.pets[0].state == .airborne(.falling))
        #expect(world.pets[0].velocity == .zero)
    }
}
