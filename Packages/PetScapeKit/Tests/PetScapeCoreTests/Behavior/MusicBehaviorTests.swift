import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("M16 music and cleanup")
struct MusicBehaviorTests {
    @Test func hysteresisToleratesShortSilenceAndRequiresANewSession() {
        var detector = MusicSessionDetector()
        #expect(detector.observe(confidence: 0.9, duration: 0.5) == nil)
        #expect(detector.observe(confidence: 0.9, duration: 0.5) == true)
        #expect(detector.observe(confidence: 0.1, duration: 0.5) == nil)
        #expect(detector.observe(confidence: 0.9, duration: 0.5) == nil)
        #expect(detector.observe(confidence: 0.1, duration: 0.5) == nil)
        #expect(detector.observe(confidence: 0.1, duration: 0.5) == false)
        #expect(detector.observe(confidence: 0.9, duration: 1) == true)
    }

    @Test func oscillationInvalidInputAndRestartCannotCreateSessions() {
        var detector = MusicSessionDetector()
        for score in [0.9, 0.5, 0.9, 0.5, Double.nan, -1, 2] {
            #expect(detector.observe(confidence: score, duration: 0.5) == nil)
        }
        detector.reset(requireSilence: true)
        #expect(detector.observe(confidence: 1, duration: 1) == nil)
        #expect(detector.observe(confidence: 0, duration: 1) == nil)
        #expect(detector.observe(confidence: 1, duration: 1) == true)
    }

    @Test func automaticExpiresWithoutRepeatingAndStopsOnMusicStop() throws {
        var world = try Self.world()
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .grounded(.dancing(.automatic)))
        let duration = world.pets[0].specialBehaviorDuration
        #expect((5...30).contains(duration))
        AutonomyTests.advance(&world, seconds: duration + 0.1)
        #expect(world.pets[0].state != .grounded(.dancing(.automatic)))
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state != .grounded(.dancing(.automatic)))
        world.apply(.setMusicPlaying(false))
        world.apply(.setActivity(world.pets[0].id, .idle))
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .grounded(.dancing(.automatic)))
        world.apply(.setMusicPlaying(false))
        #expect(world.pets[0].state == .grounded(.idle))
    }

    @Test func manualTakesOverOnceAndIgnoresMusicStopAndStart() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.setMusicPlaying(true))
        world.apply(.requestDance(id))
        #expect(world.pets[0].state == .grounded(.dancing(.manual)))
        let duration = world.pets[0].specialBehaviorDuration
        AutonomyTests.advance(&world, seconds: 1)
        world.apply(.requestDance(id))
        #expect(world.pets[0].specialBehaviorDuration == duration)
        #expect(world.pets[0].stateElapsed >= 0.99)
        world.apply(.setMusicPlaying(false))
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .grounded(.dancing(.manual)))
        AutonomyTests.advance(&world, seconds: 30)
        #expect(world.pets[0].state != .grounded(.dancing(.manual)))
    }

    @Test(arguments: [
        PetState.held, .airborne(.falling), .airborne(.rising), .grounded(.landing),
        .grounded(.preparingJump), .grounded(.climbing(wall: .left)), .grounded(.sleeping),
    ])
    func busySessionIsConsumedWithoutPendingReplay(state: PetState) throws {
        var world = try Self.world()
        world.pets[0].state = state
        world.apply(.setMusicPlaying(true))
        world.apply(.requestDance(world.pets[0].id))
        #expect(world.pets[0].state == state)
        world.pets[0].state = .walking
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .walking)
    }

    @Test func suspensionAutonomyAndSupportLossCancelDance() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestDance(id))
        world.apply(.suspendMusicBehaviors)
        #expect(world.pets[0].state == .grounded(.idle))
        world.apply(.requestDance(id))
        world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
        #expect(world.pets[0].state == .grounded(.idle))
        world.apply(.requestDance(id))
        #expect(world.pets[0].state == .grounded(.idle))
        world.apply(.configureBehavior(AutonomySettings()))
        world.apply(.requestDance(id))
        world.apply(.surfaces([]))
        _ = world.step(dt: AutonomyTests.dt)
        #expect(world.pets[0].state.kind != .dancing)
    }

    private struct EndpointRandom: RandomSource {
        var value: UInt64
        mutating func next() -> UInt64 { value }
    }

    @Test func injectedRandomCanProduceBothInclusiveBounds() {
        var minimum: any RandomSource = EndpointRandom(value: 0)
        var maximum: any RandomSource = EndpointRandom(value: .max)
        #expect(DanceSource.duration(using: &minimum) == 5)
        #expect(DanceSource.duration(using: &maximum) == 30)
    }

    @Test func durationDrawIncludesEndpointsAndReplaysSeed() throws {
        #expect(DanceSource.duration(unitRandom: 0) == 5)
        #expect(DanceSource.duration(unitRandom: 1) == 30)
        var a = try Self.world()
        var b = try Self.world()
        a.apply(.requestDance(a.pets[0].id))
        b.apply(.requestDance(b.pets[0].id))
        #expect(a.pets[0].specialBehaviorDuration == b.pets[0].specialBehaviorDuration)
        #expect(a.pets[0].animation.requestedClip == "dance")
        #expect(a.pets[0].animation.currentFrame.frameIndex == 0)
        AutonomyTests.advance(&a, seconds: 4)
        #expect(a.pets[0].animation.currentFrame.frameIndex == 0)
        #expect(a.needsSimulationSteps)
    }

    @Test func descendingDockContactCleansOnceAfterLandingWithoutMoving() throws {
        var world = try Self.fallingWorld()
        var sawLanding = false
        var sawCleanup = false
        var transitions = 0
        for _ in 0..<120 {
            let events = world.step(dt: AutonomyTests.dt)
            if world.pets[0].state == .grounded(.landing) { sawLanding = true }
            if world.pets[0].state == .grounded(.cleaning) {
                sawCleanup = true
                #expect(sawLanding)
                #expect(world.pets[0].position.y == PhysicsWorldTests.dock.y)
                #expect(world.pets[0].velocity == .zero)
                #expect(world.pets[0].attachment?.surfaceID == .dock)
            }
            transitions +=
                events.filter {
                    if case .stateChanged(_, _, .cleaning) = $0 { true } else { false }
                }.count
        }
        #expect(sawCleanup)
        AutonomyTests.advance(&world, seconds: 4)
        #expect(world.pets[0].state != .grounded(.cleaning))
        #expect(transitions == 1)
    }

    @Test func sameDockJumpDoesNotClean() throws {
        var world = try Self.fallingWorld()
        world.pets[0].flightOrigin = .jump(.dock, sourceY: 64)
        for _ in 0..<120 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state != .grounded(.cleaning))
        }
    }

    @Test(arguments: [true, false])
    func heldReleaseAboveGroundCleansOnceAfterStableLanding(useDock: Bool) throws {
        var world = try Self.fallingWorld()
        let ground = useDock ? PhysicsWorldTests.dock : PetWorldTests.floor
        if !useDock { world.apply(.surfaces([ground])) }
        world.pets[0].state = .walking
        world.pets[0].position = CGPoint(x: 600, y: ground.y)
        world.pets[0].attachment = SurfaceAttachment(surfaceID: ground.id, parameter: 0.5)
        let id = world.pets[0].id
        let interaction = InteractionID(7)
        world.apply(.interaction(id, .press(interaction)))
        world.apply(.interaction(id, .beginHold(interaction, target: CGPoint(x: 600, y: 300))))
        world.apply(.interaction(id, .release(interaction, target: CGPoint(x: 600, y: 300))))
        #expect(world.pets[0].state == .airborne(.falling))
        #expect(world.pets[0].flightOrigin == .released)
        var cleanups = 0
        var sawLanding = false
        for _ in 0..<300 {
            let events = world.step(dt: AutonomyTests.dt)
            if world.pets[0].state == .grounded(.landing) { sawLanding = true }
            if world.pets[0].state == .grounded(.cleaning) {
                #expect(sawLanding)
                #expect(world.pets[0].position.y == ground.y)
                #expect(world.pets[0].attachment?.surfaceID == ground.id)
                #expect(world.pets[0].velocity == .zero)
            }
            cleanups +=
                events.filter {
                    if case .stateChanged(_, _, .cleaning) = $0 { true } else { false }
                }.count
        }
        #expect(cleanups == 1)
        #expect(world.pets[0].state != .grounded(.cleaning))
    }

    @Test func heldReleaseLandingOnWindowDoesNotClean() throws {
        var world = try Self.fallingWorld()
        let window = Surface(
            id: SurfaceID("window:cleanup-test:top:0"), kind: .windowTop,
            y: 200, minX: 100, maxX: 1400)
        world.apply(.surfaces([PetWorldTests.floor, PhysicsWorldTests.dock, window]))
        world.pets[0].flightOrigin = .released
        for _ in 0..<120 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state != .grounded(.cleaning))
        }
        #expect(world.pets[0].attachment?.surfaceID == window.id)
    }

    @Test func floorLandingPlacementAndWalkingDoNotClean() throws {
        var world = try Self.fallingWorld()
        world.apply(.surfaces([PetWorldTests.floor]))
        for _ in 0..<240 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state != .grounded(.cleaning))
        }
        world = try Self.world()
        for _ in 0..<120 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state != .grounded(.cleaning))
        }
    }

    @Test func upwardJumpToDockDoesNotClean() throws {
        var world = try Self.fallingWorld()
        world.pets[0].flightOrigin = .jump(PetWorldTests.floor.id, sourceY: 0)
        world.pets[0].jumpSource = PetWorldTests.floor
        for _ in 0..<120 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state != .grounded(.cleaning))
        }
    }

    @Test func holdCancelsDanceAndReleaseDoesNotRestoreIt() throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.requestDance(id))
        let interaction = InteractionID(1)
        world.apply(.interaction(id, .press(interaction)))
        world.apply(.interaction(id, .beginHold(interaction, target: CGPoint(x: 600, y: 300))))
        #expect(world.pets[0].state == .held)
        world.apply(.interaction(id, .release(interaction, target: CGPoint(x: 600, y: 300))))
        #expect(world.pets[0].state == .airborne(.falling))
        #expect(world.pets[0].flightOrigin == .released)
        for _ in 0..<120 {
            _ = world.step(dt: AutonomyTests.dt)
            #expect(world.pets[0].state.kind != .dancing)
        }
    }

    @Test func pendingCleanupIsCancelledBySuspensionAndAutonomyOff() throws {
        for suspend in [true, false] {
            var world = try Self.fallingWorld()
            for _ in 0..<120 {
                _ = world.step(dt: AutonomyTests.dt)
                if world.pets[0].state == .grounded(.landing) { break }
            }
            #expect(world.pets[0].pendingDockCleanup)
            if suspend {
                world.apply(.suspendMusicBehaviors)
            } else {
                world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
            }
            AutonomyTests.advance(&world, seconds: 0.2)
            #expect(world.pets[0].state.kind != .cleaning)
            #expect(!world.pets[0].pendingDockCleanup)
        }
    }

    @Test func removingUpperJumpSourceDuringFlightPreservesCleanupProvenance() throws {
        var world = try Self.fallingWorld()
        let upper = Surface(id: SurfaceID("upper-window"), kind: .windowTop, y: 300, minX: 100, maxX: 624)
        world.apply(.surfaces([PetWorldTests.floor, PhysicsWorldTests.dock, upper]))
        world.pets[0].state = .walking
        world.pets[0].attachment = SurfaceAttachment(surfaceID: upper.id, parameter: upper.parameter(atX: 600))
        world.pets[0].velocity = .zero
        world.apply(
            .requestJump(
                world.pets[0].id,
                JumpRequest(target: .surface(.dock, x: 680), returnActivity: .walking)))
        #expect(world.pets[0].state == .grounded(.preparingJump))
        AutonomyTests.advance(&world, seconds: 0.2)
        #expect(world.pets[0].state.kind == .rising || world.pets[0].state.kind == .falling)
        world.apply(.surfaces([PetWorldTests.floor, PhysicsWorldTests.dock]))
        #expect(world.pets[0].jumpSource == nil)
        var cleaned = false
        for _ in 0..<180 {
            _ = world.step(dt: AutonomyTests.dt)
            if world.pets[0].state == .grounded(.cleaning) { cleaned = true }
        }
        #expect(cleaned)
    }

    @Test(arguments: [DanceSource.manual, .automatic])
    func stopDanceEndsOnlyTheDanceWithoutRearmingContinuousMusic(source: DanceSource) throws {
        var world = try Self.world()
        let id = world.pets[0].id
        world.apply(.setMusicPlaying(true))
        if source == .manual { world.apply(.requestDance(id)) }
        #expect(world.pets[0].state == .grounded(.dancing(source)))
        world.apply(.stopDance(id))
        #expect(world.pets[0].state == .grounded(.idle))
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .grounded(.idle))
        world.apply(.setMusicPlaying(false))
        world.apply(.setMusicPlaying(true))
        #expect(world.pets[0].state == .grounded(.dancing(.automatic)))
    }

    @Test(arguments: [PetState.airborne(.falling), .held, .grounded(.cleaning), .walking])
    func stopDanceDoesNotInterruptOtherStates(state: PetState) throws {
        var world = try Self.world()
        world.pets[0].state = state
        world.apply(.stopDance(world.pets[0].id))
        #expect(world.pets[0].state == state)
    }

    static func world() throws -> PetWorld {
        var world = try AutonomyTests.world()
        world.apply(.configureMusicDancing(true))
        world.tuning.activityWeights = [.walk: 1]
        return world
    }

    static func fallingWorld() throws -> PetWorld {
        var world = try PhysicsWorldTests.world()
        world.apply(.configureBehavior(AutonomySettings()))
        world.pets[0].state = .airborne(.falling)
        world.pets[0].attachment = nil
        world.pets[0].position = CGPoint(x: 600, y: 300)
        world.pets[0].velocity = CGVector(dx: 0, dy: -100)
        world.tuning.activityWeights = [.walk: 1]
        return world
    }
}
