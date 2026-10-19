import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Simulation-driven jump presentation")
struct JumpAnimationTests {
    static func definition(frameCount: Int, legacy: Bool = false) throws -> CharacterDefinition {
        let frames = (0..<frameCount).map {
            CharacterManifest.Frame(image: "f\($0).png", events: ["takeoff", "apex", "contact"])
        }
        let manifest = CharacterManifest(
            id: "cat", displayName: "Cat", defaultAnimation: "walk",
            canvas: .init(width: 64, height: 64), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: 0.5, y: 0.074),
            animations: [
                "walk": .init(fps: 9, frames: [.init(image: "walk.png")], nominalSpeed: 20, interruptible: false),
                "idle": .init(fps: 8, frames: frames),
                "jump-start": .init(playback: .once, fps: 30, frames: frames, interruptible: false),
                legacy ? "jump-air" : "jump": .init(fps: 12, frames: frames, interruptible: false),
                "fall": .init(fps: 12, frames: frames, interruptible: false),
                legacy ? "land" : "landing": .init(playback: .loop, fps: 12, frames: frames, interruptible: false),
            ])
        return try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
    }
    static func world(_ definition: CharacterDefinition) -> PetWorld {
        var world = PetWorld(random: SeededRandomSource(seed: 100))
        world.apply(.screens([PetWorldTests.screen]))
        world.apply(.surfaces([PetWorldTests.floor]))
        world.spawn(definition)
        _ = world.step(dt: 1.0 / 60)
        world.apply(.requestJump(world.pets[0].id, JumpRequest()))
        return world
    }
    @Test(arguments: [1, 8, 12, 24, 32])
    func sameTrajectoryForVariableFrameCounts(frameCount: Int) throws {
        var baseline = Self.world(try Fixtures.walkingDefinition())
        var authored = Self.world(try Self.definition(frameCount: frameCount))
        for _ in 0..<130 {
            _ = baseline.step(dt: 1.0 / 60)
            _ = authored.step(dt: 1.0 / 60)
            #expect(baseline.pets[0].position == authored.pets[0].position)
            #expect(baseline.pets[0].velocity == authored.pets[0].velocity)
            #expect(baseline.pets[0].state == authored.pets[0].state)
        }
    }
    @Test func normalPriorityAndWalkRateAreRestoredAfterLanding() throws {
        var world = Self.world(try Self.definition(frameCount: 32))
        world.tuning.speedScale = 1.5
        for _ in 0..<100 { _ = world.step(dt: 1.0 / 60) }
        #expect(world.pets[0].state == .walking)
        #expect(world.pets[0].animation.priority == 10)
        #expect(world.pets[0].animation.rate == 1.5)
        #expect(world.pets[0].animation.currentFrame.clip == "walk")
    }
    @Test func legacyAliasesAndPhysicalContactSelectPhaseArt() throws {
        var world = Self.world(try Self.definition(frameCount: 8, legacy: true))
        var events: [WorldEvent] = []
        for _ in 0..<9 { world.step(dt: 1.0 / 60, into: &events) }
        #expect(world.pets[0].animation.currentFrame.clip == "jump-air")
        #expect(events.filter { if case .tookOff = $0 { true } else { false } }.count == 1)
        for _ in 0..<100 {
            events.removeAll()
            world.step(dt: 1.0 / 60, into: &events)
            if events.contains(where: { if case .landed = $0 { true } else { false } }) {
                #expect(world.pets[0].animation.currentFrame.clip == "land")
                #expect(world.pets[0].state.kind == .landing)
                return
            }
        }
        Issue.record("Jump never landed")
    }
}
