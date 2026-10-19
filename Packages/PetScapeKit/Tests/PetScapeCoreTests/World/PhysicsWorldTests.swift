import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Physical world")
struct PhysicsWorldTests {
    static let dt = 1.0 / 60
    static let dock = Surface(id: .dock, kind: .dockTop, y: 64, minX: 0, maxX: 1470)
    static func world() throws -> PetWorld {
        try PetWorldTests.makeWorld(surfaces: [PetWorldTests.floor, dock]).world
    }
    @Test func lostDockFallsVisiblyAndLandsOnceWithoutRespawn() throws {
        var world = try Self.world()
        PetWorldTests.set(&world, x: 600, facing: .right)
        _ = world.step(dt: Self.dt)
        let start = world.pets[0].position
        world.apply(.surfaces([PetWorldTests.floor]))
        var events = world.step(dt: Self.dt)
        #expect(world.pets[0].state.kind == .falling)
        #expect(world.pets[0].position.y < start.y)
        #expect(world.pets[0].position.y > 0)
        #expect(world.pets[0].velocity.dy == -40)
        #expect(world.snapshot().pets[0].isVisible)
        #expect(world.pets[0].attachment == nil)
        for _ in 0..<60 { world.step(dt: Self.dt, into: &events) }
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
        #expect(world.pets[0].state == .walking)
        #expect(events.filter { if case .landed = $0 { true } else { false } }.count == 1)
        #expect(!events.contains { if case .placed = $0 { true } else { false } })
        #expect(!events.contains { if case .recovered = $0 { true } else { false } })
        #expect(world.pets[0].position.x > start.x)
    }
    @Test func heldIdleWakesWhenSupportDisappearsOrBodyNeedsRecovery() throws {
        var world = try Self.world()
        _ = world.step(dt: Self.dt)
        let id = world.pets[0].id
        world.apply(.setActivity(id, .idle))
        #expect(!world.needsSimulationSteps)
        world.apply(.surfaces([PetWorldTests.floor]))
        #expect(world.needsSimulationSteps)
        #expect(world.step(dt: Self.dt).contains(.surfaceLost(id, .dock)))
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        world.apply(.setActivity(id, .idle))
        world.pets[0].position.x = .nan
        #expect(world.needsSimulationSteps)
        #expect(world.step(dt: Self.dt).contains(.recovered(id, reason: .invalidNumbers)))
    }
    @Test func contactDoesNotRepeat() throws {
        var world = try Self.world()
        var events: [WorldEvent] = []
        for _ in 0..<600 { world.step(dt: Self.dt, into: &events) }
        #expect(!events.contains { if case .landed = $0 { true } else { false } })
    }
    @Test(arguments: [0.5, Double.nan, .infinity, -1, 0])
    func largeWorldDtHasNoEffects(dt: Double) throws {
        var world = try Self.world()
        let before = world.snapshot()
        let time = world.time
        #expect(world.step(dt: dt).isEmpty)
        #expect(world.time == time)
        #expect(world.snapshot() == before)
    }
    @Test func dockAdditionKeepsFloorAttachment() throws {
        var world = try PetWorldTests.makeWorld().world
        _ = world.step(dt: Self.dt)
        let position = world.pets[0].position
        world.apply(.surfaces([Self.dock, PetWorldTests.floor]))
        #expect(world.pets[0].position == position)
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
    }
    @Test func invalidAirborneVelocityRecovers() throws {
        var world = try Self.world()
        world.apply(.surfaces([PetWorldTests.floor]))
        _ = world.step(dt: Self.dt)
        world.pets[0].velocity.dy = .nan
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.recovered(world.pets[0].id, reason: .invalidNumbers)))
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].velocity == .zero)
        #expect(world.pets[0].position.x.isFinite)
    }
    @Test func turningPreservesNonzeroWalkFrame() throws {
        var world = try Self.world()
        PetWorldTests.set(&world, x: 1400, facing: .right, state: .turning(to: .left))
        _ = world.pets[0].animation.advance(by: 0.4)
        let frame = world.pets[0].animation.currentFrame.frameIndex
        #expect(frame > 0)
        for _ in 0..<9 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].animation.currentFrame.frameIndex == frame)
        #expect(world.pets[0].facing == .left)
    }
    @Test func tailPoseDoesNotChangeEdgeOrWalkingSpeed() throws {
        let frames = [CharacterManifest.Frame(image: "frame.png")]
        let manifest = CharacterManifest(
            id: "cat", displayName: "Cat", defaultAnimation: "walk",
            canvas: .init(width: 512, height: 512), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: 0.5, y: 0.074),
            animations: [
                "walk": .init(fps: 9, frames: frames, nominalSpeed: 20),
                "fall": .init(fps: 9, frames: frames, nominalSpeed: 900, anchor: .init(x: 0.05, y: 0.074)),
            ])
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        var world = PetWorld(random: SeededRandomSource(seed: 1))
        world.apply(.surfaces([PetWorldTests.floor]))
        world.spawn(definition)
        PetWorldTests.set(&world, x: 600, facing: .right)
        world.pets[0].animation.request(AnimationRequest(clip: "fall", priority: 90))
        #expect(world.pets[0].edgeMargin == 48)
        _ = world.step(dt: Self.dt)
        #expect(abs(world.pets[0].position.x - 600.3333333333334) < 1e-9)
    }
    @Test func noSurfaceWaitsWithoutFrameDemandAndResumesOnEnvironment() throws {
        var world = try Self.world()
        _ = world.step(dt: Self.dt)
        world.apply(.surfaces([]))
        #expect(!world.needsSimulationSteps)
        #expect(!world.needsAnimationFrames)
        world.apply(.surfaces([PetWorldTests.floor]))
        #expect(world.needsSimulationSteps)
        for _ in 0..<60 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
    }
    @Test func hiddenRecoverySnapshotStillNeedsSteps() throws {
        var world = try Self.world()
        _ = world.step(dt: Self.dt)
        world.pets[0].position.x = .nan
        _ = world.step(dt: Self.dt)
        #expect(!world.snapshot().pets[0].isVisible)
        #expect(world.needsSimulationSteps)
        _ = world.step(dt: Self.dt)
        #expect(world.snapshot().pets[0].isVisible)
    }
    @Test func airborneWithAttachmentRecoversAsInvalidContact() throws {
        var world = try Self.world()
        world.pets[0].state = .airborne(.falling)
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.recovered(world.pets[0].id, reason: .invalidContact)))
    }
    @Test func unsupportedFootDetachesOnce() throws {
        var world = try Self.world()
        _ = world.step(dt: Self.dt)
        let tiny = Surface(id: .dock, kind: .dockTop, y: 64, minX: 100, maxX: 120)
        world.apply(.surfaces([tiny, PetWorldTests.floor]))
        var events: [WorldEvent] = []
        for _ in 0..<60 { world.step(dt: Self.dt, into: &events) }
        #expect(events.filter { if case .surfaceLost = $0 { true } else { false } }.count == 1)
        #expect(world.pets[0].attachment?.surfaceID == PetWorldTests.floor.id)
    }
    @Test func seededReplayMatches() throws {
        var a = try Self.world()
        var b = try Self.world()
        a.apply(.surfaces([PetWorldTests.floor]))
        b.apply(.surfaces([PetWorldTests.floor]))
        for _ in 0..<120 {
            #expect(a.step(dt: Self.dt) == b.step(dt: Self.dt))
            #expect(a.snapshot() == b.snapshot())
            #expect(a.pets[0].velocity == b.pets[0].velocity)
        }
    }
    @Test func airborneTimeoutDoesNotResetOnStateChanges() throws {
        var world = try Self.world()
        _ = world.step(dt: Self.dt)
        world.apply(.screens([]))
        world.apply(.surfaces([Surface(id: SurfaceID("far"), kind: .screenBottom, y: 0, minX: 5000, maxX: 6000)]))
        var events: [WorldEvent] = []
        for _ in 0..<181 { world.step(dt: Self.dt, into: &events) }
        #expect(events.contains(.recovered(world.pets[0].id, reason: .airborneTimeout)))
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].attachment?.surfaceID == SurfaceID("far"))
    }
    static func phaseWorld(defaultClip: String = "walk", next: String? = nil) throws -> PetWorld {
        let manifest = CharacterManifest(
            id: "phases", displayName: "Phases", defaultAnimation: defaultClip,
            canvas: .init(width: 64, height: 64), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: 0.5, y: 0.074),
            animations: [
                "walk": .init(fps: 9, frames: [.init(image: "w.png")], nominalSpeed: 20),
                "fall": .init(
                    playback: .once, fps: 60,
                    frames: [.init(image: "a.png"), .init(image: "b.png")], next: next),
            ])
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        var world = PetWorld(random: SeededRandomSource(seed: 2))
        world.apply(.screens([PetWorldTests.screen]))
        world.apply(.surfaces([Self.dock, PetWorldTests.floor]))
        world.spawn(definition)
        _ = world.step(dt: Self.dt)
        world.apply(.surfaces([PetWorldTests.floor]))
        return world
    }
    @Test func realFallAsDefaultStillAdvances() throws {
        var world = try Self.phaseWorld(defaultClip: "fall")
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].animation.currentFrame.clip == "fall")
        #expect(world.pets[0].animation.currentFrame.frameIndex == 1)
    }
    @Test func physicalPhaseDoesNotAutoChain() throws {
        var world = try Self.phaseWorld(next: "walk")
        for _ in 0..<4 { _ = world.step(dt: Self.dt) }
        #expect(world.pets[0].state.kind == .falling)
        #expect(world.pets[0].animation.currentFrame.clip == "fall")
        #expect(world.needsSimulationSteps)
        #expect(!world.needsAnimationFrames)
    }
}
