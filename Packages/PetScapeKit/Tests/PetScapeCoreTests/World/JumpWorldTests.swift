import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Jump execution")
struct JumpWorldTests {
    static let dt = 1.0 / 60
    static func world() throws -> PetWorld {
        var world = try PetWorldTests.makeWorld().world
        PetWorldTests.set(&world, x: 600, facing: .right)
        _ = world.step(dt: Self.dt)
        return world
    }
    static func eventsThroughLanding(_ world: inout PetWorld) -> [WorldEvent] {
        var events: [WorldEvent] = []
        for _ in 0..<130 { world.step(dt: Self.dt, into: &events) }
        return events
    }
    @Test func walkingJumpReturnsWalkingWithOneLaunchApexAndContact() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        #expect(world.pets[0].state.kind == .preparingJump)
        var events: [WorldEvent] = []
        for _ in 0..<8 { world.step(dt: Self.dt, into: &events) }
        #expect(!events.contains(.tookOff(id)))
        world.step(dt: Self.dt, into: &events)
        #expect(events.contains(.tookOff(id)))
        #expect(world.pets[0].velocity.dy > 0)
        events += Self.eventsThroughLanding(&world)
        #expect(events.filter { $0 == .tookOff(id) }.count == 1)
        #expect(events.filter { $0 == .apex(id) }.count == 1)
        #expect(events.filter { if case .landed = $0 { true } else { false } }.count == 1)
        #expect(world.pets[0].state == .walking)
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
    }
    @Test func idleJumpReturnsIdleAndEventuallyStopsFrames() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.setActivity(id, .idle))
        #expect(!world.needsSimulationSteps)
        world.apply(.requestJump(id, JumpRequest(returnActivity: .idle)))
        _ = Self.eventsThroughLanding(&world)
        #expect(world.pets[0].state == .grounded(.idle))
        #expect(world.pets[0].velocity == .zero)
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        #expect(!world.needsSimulationSteps)
        #expect(!world.needsAnimationFrames)
        world.apply(.requestJump(id, JumpRequest(returnActivity: .idle)))
        #expect(world.pets[0].state.kind == .preparingJump)
    }
    @Test func duplicateRequestIsRejectedWithoutSecondLaunch() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        world.apply(.requestJump(id, JumpRequest()))
        let events = Self.eventsThroughLanding(&world)
        #expect(events.contains(.jumpRejected(id, .busy)))
        #expect(events.filter { $0 == .tookOff(id) }.count == 1)
    }
    @Test func sourceLossWinsOverLaunchDeadline() throws {
        var world = try PhysicsWorldTests.world()
        _ = world.step(dt: Self.dt)
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        for _ in 0..<8 { _ = world.step(dt: Self.dt) }
        world.apply(.surfaces([PetWorldTests.floor]))
        let events = world.step(dt: Self.dt)
        #expect(!events.contains(.tookOff(id)))
        #expect(events.contains(.jumpCancelled(id)))
        #expect(world.pets[0].state.kind == .falling)
    }
    @Test(arguments: [false, true])
    func launchRevalidatesInterveningSupportAndCeiling(changeCeiling: Bool) throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        for _ in 0..<8 { _ = world.step(dt: Self.dt) }
        if changeCeiling {
            let old = PetWorldTests.screen
            world.apply(
                .screens([
                    ScreenDescriptor(
                        id: old.id, frame: old.frame,
                        visibleFrame: CGRect(x: 0, y: 0, width: old.frame.width, height: 61),
                        backingScale: old.backingScale, isPrimary: old.isPrimary)
                ]))
        } else {
            world.apply(.surfaces([PetWorldTests.floor, PhysicsWorldTests.dock]))
        }
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.jumpCancelled(id)))
        #expect(!events.contains(.tookOff(id)))
        #expect(world.pets[0].position.y == 0)
    }
    @Test func unrelatedSurfaceChangePreservesAcceptedLaunchAndBody() throws {
        var world = try PetWorldTests.makeWorld(seed: 3).world
        _ = world.step(dt: Self.dt)
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest(target: .horizontal(10))))
        let position = world.pets[0].position
        world.apply(
            .surfaces([
                PetWorldTests.floor,
                Surface(id: SurfaceID("below"), kind: .screenBottom, y: -100, minX: 0, maxX: 1470),
            ]))
        #expect(world.pets[0].position == position)
        var events: [WorldEvent] = []
        for _ in 0..<9 { world.step(dt: Self.dt, into: &events) }
        #expect(events.contains(.tookOff(id)))
        #expect(!events.contains(.jumpCancelled(id)))
    }
    @Test func cooldownRejectsImmediatelyAfterLanding() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        world.apply(.requestJump(id, JumpRequest()))
        #expect(world.step(dt: Self.dt).contains(.jumpRejected(id, .cooldown)))
    }
    @Test func targetChangeDuringFlightCancelsPlanWithoutTeleport() throws {
        var world = try Self.world()
        let dock = Surface(id: .dock, kind: .dockTop, y: 64, minX: 0, maxX: 1470)
        world.apply(.surfaces([PetWorldTests.floor, dock]))
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest(target: .surface(.dock, x: 620))))
        for _ in 0..<12 { _ = world.step(dt: Self.dt) }
        let position = world.pets[0].position
        let velocity = world.pets[0].velocity
        world.apply(.surfaces([PetWorldTests.floor]))
        #expect(world.pets[0].position == position)
        #expect(world.pets[0].velocity == velocity)
        let events = Self.eventsThroughLanding(&world)
        #expect(events.contains(.jumpCancelled(id)))
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
    }
    @Test(arguments: [CGFloat(-80), 80])
    func shortJumpHasActualSweptContactWithinOnePoint(offset: CGFloat) throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.setActivity(id, .idle))
        let start = world.pets[0].position
        world.apply(.requestJump(id, JumpRequest(target: .horizontal(Double(offset)), returnActivity: .idle)))
        var events: [WorldEvent] = []
        for _ in 0..<130 { world.step(dt: Self.dt, into: &events) }
        #expect(abs(world.pets[0].position.x - (start.x + offset)) <= 1)
        #expect(world.pets[0].position.y == 0)
        #expect(world.pets[0].state == .grounded(.idle))
        #expect(events.contains(.landed(id, PetWorldTests.floor.id)))
    }
    @Test func targetRaisedAboveFootCannotCaptureFromUnderneath() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest(returnActivity: .idle)))
        for _ in 0..<12 { _ = world.step(dt: Self.dt) }
        let previous = world.pets[0].position
        let high = Surface(id: .dock, kind: .dockTop, y: 160, minX: 0, maxX: 1470)
        world.apply(.surfaces([Self.floorSurface, high]))
        #expect(world.pets[0].position == previous)
        _ = Self.eventsThroughLanding(&world)
        #expect(world.pets[0].attachment?.surfaceID == Self.floorSurface.id)
    }
    static var floorSurface: Surface { PetWorldTests.floor }
    @Test func unknownPetAndUnreachableTargetAreRejected() throws {
        var world = try Self.world()
        world.apply(.requestJump(PetID(999), JumpRequest()))
        #expect(world.step(dt: Self.dt).contains(.jumpRejected(PetID(999), .unknownPet)))
        let id = world.pets[0].id
        let before = world.pets[0].position
        world.apply(.requestJump(id, JumpRequest(target: .horizontal(81))))
        var events: [WorldEvent] = []
        world.drainEvents(into: &events)
        #expect(events.contains(.jumpRejected(id, .unreachable)))
        #expect(world.pets[0].position == before)
    }
}
