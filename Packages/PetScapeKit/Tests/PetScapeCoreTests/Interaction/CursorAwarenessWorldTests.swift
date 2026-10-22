import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("Cursor awareness in PetWorld")
struct CursorAwarenessWorldTests {
    private static let dt = 1.0 / 60

    private static func world() throws -> PetWorld {
        var world = try PetWorldTests.makeWorld(seed: 42).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
        world.pets[0].activity = .walk
        world.pets[0].activityDeadline = 20
        world.pets[0].stateElapsed = 0.5
        world.apply(.setCursorReactionsEnabled(true))
        world.apply(.setCursorLocation(CGPoint(x: 700, y: 48)))
        return world
    }

    @Test func boundedDwellFreezesAndResumesTheSavedWalkActivity() throws {
        var world = try Self.world()
        let decisions = world.pets[0].activityDecisionCount
        for _ in 0..<23 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state != .grounded(.reactingToCursor))
        let positionBeforeReaction = world.pets[0].position
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].state == .grounded(.reactingToCursor))
        #expect(world.pets[0].activityDecisionCount == decisions)
        #expect(world.pets[0].position == positionBeforeReaction)
        #expect(world.pets[0].animation.requestedClip == "curious")

        for _ in 0..<121 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .walking)
        #expect(world.pets[0].activity == .walk)
        #expect(abs((world.pets[0].activityDeadline - world.time) - 19.6) < 0.02)
    }

    @Test func disablingCursorReactionsCancelsTheCurrentReaction() throws {
        var world = try Self.world()
        for _ in 0..<24 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state == .grounded(.reactingToCursor))
        world.apply(.setCursorReactionsEnabled(false))
        #expect(world.pets[0].state == .grounded(.idle))
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state != .grounded(.reactingToCursor))
    }

    @Test func nonFiniteCursorIsDiscarded() throws {
        var world = try Self.world()
        world.apply(.setCursorLocation(CGPoint(x: CGFloat.infinity, y: 10)))
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state != .grounded(.reactingToCursor))
    }
}
