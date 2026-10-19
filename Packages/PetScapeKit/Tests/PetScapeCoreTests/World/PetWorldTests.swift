import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

/// T5.3: `PetWorld.step` and the MVP state machine (state-machines.md#test-obligations), AC-07/08/09/11.
@Suite("PetWorld — MVP walking")
struct PetWorldTests {
    static let dt = 1.0 / 60
    static let screen = ScreenDescriptor(
        id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 853), backingScale: 2, isPrimary: true)
    static let floor = Surface.screenBottom(of: screen)

    /// A world with one screen, its bottom surface and one 96 pt walker.
    static func makeWorld(
        seed: UInt64 = 1, surfaces: [Surface] = [floor], nominalSpeed: Double? = 20, anchorX: Double = 0.5
    ) throws -> (world: PetWorld, id: PetID) {
        var world = PetWorld(random: SeededRandomSource(seed: seed))
        world.apply(.screens([screen]))
        world.apply(.surfaces(surfaces))
        let id = world.spawn(try Fixtures.walkingDefinition(nominalSpeed: nominalSpeed, anchorX: anchorX))
        return (world, id)
    }

    /// Puts the pet at `x` facing `facing`, walking.
    static func set(_ world: inout PetWorld, x: CGFloat, facing: Facing, state: PetState = .walking) {
        let surface = world.surfaces.spawnSurface!
        world.pets[0].position = CGPoint(x: x, y: surface.y)
        world.pets[0].attachment = SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atX: x))
        world.pets[0].facing = facing
        world.pets[0].animation.setFacing(facing)
        world.pets[0].state = state
        world.pets[0].stateElapsed = 0
    }

    // MARK: Spawning

    @Test func spawnPlacesThePetOnTheSurfaceInsideTheMargins() throws {
        let (world, id) = try Self.makeWorld()
        let pet = try #require(world.pet(id))
        #expect(pet.state == .spawning)
        #expect(pet.attachment?.surfaceID == Self.floor.id)
        #expect(pet.position.y == 0)
        #expect((48...1422).contains(pet.position.x))
        #expect(pet.animation.currentFrame.clip == "walk")
        #expect(pet.animation.currentFrame.frameIndex == 0)
        #expect(world.snapshot().pets.first?.isVisible == true)
    }

    @Test func spawnIsDeterministicForASeedAndVariesAcrossSeeds() throws {
        let a = try Self.makeWorld(seed: 42).world.snapshot()
        let b = try Self.makeWorld(seed: 42).world.snapshot()
        #expect(a == b)
        let positions = Set(try (1...8).map { try Self.makeWorld(seed: $0).world.pets[0].position.x })
        #expect(positions.count > 1)
        let facings = Set(try (1...16).map { try Self.makeWorld(seed: $0).world.pets[0].facing })
        #expect(facings == [.left, .right])
    }

    @Test func withoutASurfaceThePetWaitsInvisibleAndIsPlacedWhenOneAppears() throws {
        var (world, id) = try Self.makeWorld(surfaces: [])
        #expect(world.pet(id)?.attachment == nil)
        #expect(world.snapshot().pets.first?.isVisible == false)
        _ = world.step(dt: Self.dt)
        #expect(world.pet(id)?.state == .spawning)

        world.apply(.surfaces([Self.floor]))
        #expect(world.pet(id)?.attachment?.surfaceID == Self.floor.id)
        #expect(world.snapshot().pets.first?.isVisible == true)
    }

    @Test func spawningWalksAfterOneStep() throws {
        var (world, id) = try Self.makeWorld()
        let events = world.step(dt: Self.dt)
        #expect(world.pet(id)?.state == .walking)
        #expect(events.contains(.stateChanged(id, from: .spawning, to: .walking)))
    }

    // MARK: Walking (AC-07)

    @Test(arguments: [Facing.right, .left])
    func walksAtNominalSpeedWithinFivePercentOverTenSeconds(facing: Facing) throws {
        let wide = Surface(id: SurfaceID("wide"), kind: .screenBottom, y: 0, minX: -2000, maxX: 2000)
        var (world, id) = try Self.makeWorld(surfaces: [wide])
        world.apply(.screens([]))  // no bounds check for this synthetic surface
        Self.set(&world, x: 0, facing: facing)
        for _ in 0..<600 { _ = world.step(dt: Self.dt) }
        let distance = abs(try #require(world.pet(id)).position.x)
        #expect(abs(distance - 200) <= 10)  // 20 pt/s × 10 s ± 5%
        #expect(world.pet(id)?.state == .walking)
    }

    @Test func walkSpeedFollowsSpeedScaleAndFallsBackWithoutNominalSpeed() throws {
        var (world, id) = try Self.makeWorld(nominalSpeed: nil)
        Self.set(&world, x: 700, facing: .right)
        for _ in 0..<30 { _ = world.step(dt: Self.dt) }
        let fallbackX = try #require(world.pet(id)).position.x
        #expect(abs(fallbackX - 710) < 1e-9)  // fallbackWalkSpeed 20 pt/s

        var (scaled, scaledID) = try Self.makeWorld(nominalSpeed: 30)
        scaled.tuning.speedScale = 1.5
        Self.set(&scaled, x: 700, facing: .left)
        for _ in 0..<30 { _ = scaled.step(dt: Self.dt) }
        let scaledX = try #require(scaled.pet(scaledID)).position.x
        #expect(abs(scaledX - 677.5) < 1e-9)
    }

    @Test func walkingAdvancesTheClipAndForwardsFootsteps() throws {
        var (world, id) = try Self.makeWorld()
        Self.set(&world, x: 700, facing: .right)
        var events: [WorldEvent] = []
        for _ in 0..<80 { world.step(dt: Self.dt, into: &events) }  // 1.33 s ≈ 12 frames at 9 fps
        let footsteps = events.filter {
            if case .animationEvent(id, let event) = $0, event.kind == .frame("footstep") { return true }
            return false
        }
        #expect(footsteps.count == 3)  // frames 2 and 6 of the first cycle, frame 2 of the second
    }

    @Test func walkingLeftMirrorsRightFacingArt() throws {
        var (world, _) = try Self.makeWorld()
        Self.set(&world, x: 700, facing: .left)
        #expect(world.snapshot().pets[0].frame.mirrored)
        Self.set(&world, x: 700, facing: .right)
        #expect(!world.snapshot().pets[0].frame.mirrored)
    }

    // MARK: Edges and turning (AC-08, AC-09)

    @Test func reachingTheEdgeClampsAndStartsTurning() throws {
        var (world, id) = try Self.makeWorld()
        Self.set(&world, x: 1421.9, facing: .right)
        let events = world.step(dt: Self.dt)
        #expect(world.pet(id)?.position.x == 1422)  // 1470 − 48
        #expect(world.pet(id)?.state == .turning(to: .left))
        #expect(events.contains(.edgeReached(id)))
        #expect(events.contains(.stateChanged(id, from: .walking, to: .turning)))
    }

    @Test func turningHoldsStillOnItsFrameForTurnHoldThenWalksBackMirrored() throws {
        var (world, id) = try Self.makeWorld()
        Self.set(&world, x: 1422, facing: .right, state: .turning(to: .left))
        let frameBefore = try #require(world.pet(id)).animation.currentFrame
        // 0.15 s = 9 steps at 60 Hz: still turning after 8.
        for _ in 0..<8 { _ = world.step(dt: Self.dt) }
        let holding = try #require(world.pet(id))
        #expect(holding.state == .turning(to: .left))
        #expect(holding.position.x == 1422)
        #expect(holding.animation.currentFrame == frameBefore)

        let events = world.step(dt: Self.dt)
        let turned = try #require(world.pet(id))
        #expect(turned.state == .walking)
        #expect(turned.facing == .left)
        #expect(turned.animation.currentFrame.mirrored)
        #expect(turned.animation.currentFrame.frameIndex == frameBefore.frameIndex)
        #expect(events.contains(.stateChanged(id, from: .turning, to: .walking)))

        _ = world.step(dt: Self.dt)
        #expect(try #require(world.pet(id)).position.x < 1422)
    }

    @Test(arguments: [0.5, 0.3, 0.8])
    func oneHundredTurnsWithoutDriftStuckStatesOrLeavingTheSurface(anchorX: Double) throws {
        let walkway = Surface(id: SurfaceID("walkway"), kind: .screenBottom, y: 0, minX: 100, maxX: 500)
        var (world, id) = try Self.makeWorld(seed: 7, surfaces: [walkway], anchorX: anchorX)
        let margin = CGFloat(max(anchorX, 1 - anchorX)) * 96
        var edges: [CGFloat] = []
        var stepsSinceEdge = 0
        var events: [WorldEvent] = []
        let crossing = Int((400 / 20 + 1) * 60)  // longest possible walk between edges, in steps
        var snapshot = RenderSnapshot()
        while edges.count < 100 {
            events.removeAll(keepingCapacity: true)
            world.step(dt: Self.dt, into: &events)
            let pet = try #require(world.pet(id))
            world.writeSnapshot(into: &snapshot)
            let rect = snapshot.pets[0].spriteRect
            // AC-08: the sprite never extends beyond the walkable segment ends.
            #expect(rect.minX >= walkway.minX - 1e-9 && rect.maxX <= walkway.maxX + 1e-9)
            #expect(pet.position.y == 0)
            stepsSinceEdge += 1
            if events.contains(.edgeReached(id)) {
                edges.append(pet.position.x)
                stepsSinceEdge = 0
            }
            try #require(stepsSinceEdge <= crossing, "stuck: no edge for \(stepsSinceEdge) steps")
            #expect(!events.contains { if case .recovered = $0 { true } else { false } })
        }
        // No drift: every turn happens exactly at the same two clamped positions.
        #expect(Set(edges) == [100 + margin, 500 - margin])
    }

    // MARK: Pause (AC-11)

    @Test func notSteppingFreezesFrameAndPositionAndResumingContinuesWithoutAJump() throws {
        var (world, id) = try Self.makeWorld()
        Self.set(&world, x: 500, facing: .right)
        for _ in 0..<30 { _ = world.step(dt: Self.dt) }
        let paused = world.snapshot()
        // Paused: the runtime stops stepping; nothing changes however long the pause.
        #expect(world.snapshot() == paused)
        _ = world.step(dt: Self.dt)
        let resumed = try #require(world.pet(id))
        #expect(abs(resumed.position.x - paused.pets[0].position.x - 20.0 / 60) < 1e-9)
        let frameDelta = resumed.animation.currentFrame.frameIndex - paused.pets[0].frame.frameIndex
        #expect(frameDelta == 0 || frameDelta == 1)
    }

    // MARK: Surface changes

    @Test func movedSurfaceReprojectsByParameterAndClampsToTheNewMargins() throws {
        let shelf = Surface(id: SurfaceID("dock"), kind: .dockTop, y: 70, minX: 200, maxX: 1200)
        var (world, id) = try Self.makeWorld(surfaces: [shelf])
        Self.set(&world, x: 450, facing: .right)  // parameter 0.25

        let wider = Surface(id: SurfaceID("dock"), kind: .dockTop, y: 80, minX: 0, maxX: 1400)
        world.apply(.surfaces([wider]))
        #expect(world.pet(id)?.position == CGPoint(x: 350, y: 80))

        Self.set(&world, x: 1300, facing: .right)
        let narrower = Surface(id: SurfaceID("dock"), kind: .dockTop, y: 80, minX: 300, maxX: 900)
        world.apply(.surfaces([narrower]))
        #expect(world.pet(id)?.position.x == 852)  // clamped to 900 − 48
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.edgeReached(id)))
    }

    /// M7 replaces the MVP teleport with visible physical falling and exactly one contact.
    @Test func removedSurfaceFallsOntoTheRemainingOneWithoutRespawn() throws {
        let shelf = Surface(id: .dock, kind: .dockTop, y: 70, minX: 200, maxX: 1200)
        var (world, id) = try Self.makeWorld(surfaces: [Self.floor, shelf])
        _ = world.step(dt: Self.dt)
        world.apply(.surfaces([Self.floor]))
        var events = world.step(dt: Self.dt)
        #expect(events.contains(.surfaceLost(id, shelf.id)))
        #expect(world.pet(id)?.state == .airborne(.falling))
        #expect(world.snapshot().pets[0].isVisible)
        for _ in 0..<60 { world.step(dt: Self.dt, into: &events) }
        #expect(events.filter { if case .landed = $0 { true } else { false } }.count == 1)
        #expect(!events.contains { if case .placed = $0 { true } else { false } })
        #expect(world.pet(id)?.attachment?.surfaceID == Self.floor.id)
        #expect(world.pet(id)?.state == .walking)
    }

    @Test func lostSurfaceFallsAtSameXAndFacingWhenAtRestAndDockShowDoesNotLift() throws {
        let dock = Surface(id: .dock, kind: .dockTop, y: 70, minX: 0, maxX: 1470)
        var (world, id) = try Self.makeWorld(surfaces: [dock, Self.floor])
        Self.set(&world, x: 600, facing: .left)
        world.apply(.surfaces([Self.floor]))
        var events: [WorldEvent] = []
        for _ in 0..<60 {
            world.step(dt: Self.dt, into: &events)
            if world.pet(id)?.attachment?.surfaceID == Self.floor.id { break }
        }
        #expect(world.pet(id)?.position == CGPoint(x: 600, y: 0))
        #expect(world.pet(id)?.facing == .left)
        #expect(events.contains(.landed(id, Self.floor.id)))
        #expect(!events.contains { if case .placed = $0 { true } else { false } })
        world.apply(.surfaces([dock, Self.floor]))
        #expect(world.pet(id)?.position.y == 0)
        #expect(world.pet(id)?.attachment?.surfaceID == Self.floor.id)
    }

    @Test func unsupportedReplacementUsesBoundedExceptionalRecovery() throws {
        let floor = Surface(id: SurfaceID("floor"), kind: .screenBottom, y: 0, minX: 0, maxX: 1000)
        let wide = Surface(id: .dock, kind: .dockTop, y: 70, minX: 0, maxX: 1470)
        var (world, id) = try Self.makeWorld(surfaces: [wide])
        Self.set(&world, x: 980, facing: .right)
        world.apply(.surfaces([floor]))
        var events = world.step(dt: Self.dt)
        #expect(try #require(world.pet(id)).position.y > 0)  // no immediate placement on unsupported x
        for _ in 0..<120 { world.step(dt: Self.dt, into: &events) }
        let pet = try #require(world.pet(id))
        #expect(pet.attachment?.surfaceID == floor.id)
        #expect((48...952).contains(pet.position.x))
        #expect(events.contains { if case .recovered = $0 { true } else { false } })
    }

    @Test func missingSupportOnAnotherScreenUsesBoundedRecovery() throws {
        let other = Surface(id: SurfaceID("other"), kind: .screenBottom, y: 0, minX: 3000, maxX: 4000)
        var (world, id) = try Self.makeWorld()
        let wide = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 4000, height: 956),
            visibleFrame: CGRect(x: 0, y: 0, width: 4000, height: 956), backingScale: 2, isPrimary: true)
        world.apply(.screens([wide]))
        Self.set(&world, x: 600, facing: .left)
        world.apply(.surfaces([other]))
        var events: [WorldEvent] = []
        for _ in 0..<120 { world.step(dt: Self.dt, into: &events) }
        let x = try #require(world.pet(id)?.position.x)
        #expect((3048...3952).contains(x))
        #expect(world.pet(id)?.attachment?.surfaceID == other.id)
        #expect(events.contains { if case .recovered = $0 { true } else { false } })
    }

    @Test func leavingEveryScreenRecoversOutOfBounds() throws {
        var (world, id) = try Self.makeWorld()
        _ = world.step(dt: Self.dt)
        let elsewhere = ScreenDescriptor(
            id: ScreenID(2), frame: CGRect(x: 5000, y: 0, width: 800, height: 600),
            visibleFrame: CGRect(x: 5000, y: 0, width: 800, height: 600), backingScale: 1, isPrimary: true)
        world.apply(.screens([elsewhere]))
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.recovered(id, reason: .outOfBounds)))
    }

    @Test func invalidNumbersRecover() throws {
        var (world, id) = try Self.makeWorld()
        Self.set(&world, x: 700, facing: .right, state: .turning(to: .left))
        world.pets[0].position.x = .nan
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.recovered(id, reason: .invalidNumbers)))
        _ = world.step(dt: Self.dt)
        #expect(try #require(world.pet(id)).position.x.isFinite)
    }

    @Test func interruptThresholdsFollowTheStateTable() {
        #expect(PetState.walking.interruptThreshold == 80)
        #expect(PetState.spawning.interruptThreshold == 90)
        #expect(PetState.turning(to: .left).interruptThreshold == 90)
    }
}
