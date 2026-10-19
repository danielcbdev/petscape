import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("M9 autonomous behavior")
struct AutonomyTests {
    static let dt = 1.0 / 60

    static func world(seed: UInt64 = 42, energy: Double = 0.7) throws -> PetWorld {
        var world = try PetWorldTests.makeWorld(seed: seed).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        world.pets[0].needs = Needs(energy: energy)
        world.apply(.configureBehavior(AutonomySettings()))
        return world
    }

    static func advance(_ world: inout PetWorld, seconds: Double) {
        for _ in 0..<Int((seconds / Self.dt).rounded()) { _ = world.step(dt: Self.dt) }
    }

    @Test func energyAndPersonalityAreFiniteClampedValues() {
        #expect(Needs(energy: -1).energy == 0)
        #expect(Needs(energy: 5).energy == 1)
        #expect(Needs(energy: .nan).energy == 0.7)
        var needs = Needs()
        needs.advance(by: 300, sleeping: false)
        #expect(needs.energy == 0)
        needs.advance(by: 45, sleeping: true)
        #expect(needs.energy == 1)
        needs.advance(by: .infinity, sleeping: false)
        #expect(needs.energy == 1)
        let personality = Personality(curiosity: .nan, playfulness: 4, laziness: -1, sociability: .infinity)
        #expect(personality.curiosity == 0.5)
        #expect(personality.playfulness == 1)
        #expect(personality.laziness == 0)
        #expect(personality.sociability == 0.5)
    }

    @Test func settingsClampAndDefaultBehaviorIsEnabled() {
        #expect(PetSettings().behavior.isEnabled)
        #expect(PetSettings(scale: .nan, speed: .infinity).scale == 1)
        #expect(PetSettings(scale: 0, speed: 9).scale == 0.5)
        #expect(PetSettings(scale: 0, speed: 9).speed == 2)
    }

    @Test func weightedDrawRejectsInvalidWeightsAndHasBoundedFallback() {
        var random: any RandomSource = SeededRandomSource(seed: 42)
        #expect(
            ActivitySelector.select(
                [
                    ActivityCandidate(.walk, weight: .nan), ActivityCandidate(.sleep, weight: -2),
                    ActivityCandidate(.jump, weight: .infinity), ActivityCandidate(.sit, weight: 1),
                ], previous: nil, repetitions: 0, random: &random) == .sit)
        #expect(
            ActivitySelector.select(
                [ActivityCandidate(.walk, weight: 0)], previous: nil,
                repetitions: 0, random: &random) == .idle)
    }

    @Test func seededWeightedDrawReplaysAndRepeatCapAllowsAnAlternative() {
        var a: any RandomSource = SeededRandomSource(seed: 42)
        var b: any RandomSource = SeededRandomSource(seed: 42)
        let candidates = [ActivityCandidate(.walk, weight: 4), ActivityCandidate(.idle, weight: 2)]
        var choices: [Activity] = []
        for _ in 0..<100 {
            let left = ActivitySelector.select(candidates, previous: nil, repetitions: 0, random: &a)
            let right = ActivitySelector.select(candidates, previous: nil, repetitions: 0, random: &b)
            #expect(left == right)
            choices.append(left)
        }
        #expect(Set(choices) == [.walk, .idle])
        #expect(ActivitySelector.select(candidates, previous: .walk, repetitions: 3, random: &a) == .idle)
        #expect(
            ActivitySelector.select(
                [ActivityCandidate(.walk, weight: 4)], previous: .walk,
                repetitions: 3, random: &a) == .walk)
    }

    @Test func tiredSeed42SleepsWithinTwoDecisionsAndWakeIsBounded() throws {
        var world = try Self.world(energy: 0.05)
        world.pets[0].personality = Personality(laziness: 1)
        Self.advance(&world, seconds: 0.7)
        #expect(world.pets[0].state == .grounded(.sleeping))
        #expect(world.pets[0].activityDecisionCount <= 2)
        #expect(world.needsSimulationSteps)
        #expect(world.preferredFramesPerSecond <= 4)
        let asleepEnergy = world.pets[0].needs.energy
        Self.advance(&world, seconds: 1)
        #expect(world.pets[0].needs.energy > asleepEnergy)
        world.apply(.wake(world.pets[0].id))
        #expect(world.pets[0].state == .grounded(.wakingUp))
        Self.advance(&world, seconds: 0.5)
        #expect(world.pets[0].state == .grounded(.idle))
    }

    @Test func noStepMeansNoEnergyTimeCooldownOrDecisionAdvancement() throws {
        var world = try Self.world(energy: 0.05)
        Self.advance(&world, seconds: 1)
        let before = world.pets[0]
        let time = world.time
        for _ in 0..<100 { _ = world.snapshot(); _ = world.needsSimulationSteps }
        #expect(world.time == time)
        #expect(world.pets[0].needs == before.needs)
        #expect(world.pets[0].activityDecisionCount == before.activityDecisionCount)
        #expect(world.pets[0].stateElapsed == before.stateElapsed)
    }

    @Test(arguments: [
        GroundedState.sitting, .sleeping, .sittingDown, .standingUp, .lyingDown, .wakingUp, .stretching, .observing,
    ])
    func supportLossInterruptsEveryRestState(state: GroundedState) throws {
        var world = try PhysicsWorldTests.world()
        _ = world.step(dt: Self.dt)
        world.pets[0].state = .grounded(state)
        world.apply(.surfaces([PetWorldTests.floor]))
        let events = world.step(dt: Self.dt)
        #expect(world.pets[0].state == .airborne(.falling))
        #expect(events.contains(.surfaceLost(world.pets[0].id, PhysicsWorldTests.dock.id)))
    }

    @Test func restPolicyAndAutonomyDisableWakeSleepingPet() throws {
        var world = try Self.world(energy: 0.05)
        Self.advance(&world, seconds: 0.7)
        world.apply(.configureBehavior(AutonomySettings(restEnabled: false)))
        Self.advance(&world, seconds: 0.5)
        #expect(world.pets[0].state == .grounded(.idle))
        Self.advance(&world, seconds: 100)
        #expect(world.pets[0].state != .grounded(.sleeping))
        world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
        #expect(!world.behavior.isEnabled)
    }

    @Test func noRandomDecisionsPerFrameDuringActivity() throws {
        var world = try Self.world(energy: 0.05)
        Self.advance(&world, seconds: 1)
        let count = world.pets[0].activityDecisionCount
        Self.advance(&world, seconds: 10)
        #expect(world.pets[0].activityDecisionCount == count)
    }

    @Test func rejectedAutonomousJumpWaitsAtLeastTwoSeconds() throws {
        var world = try Self.world()
        world.pets[0].activityDeadline = world.time
        let old = PetWorldTests.screen
        world.apply(
            .screens([
                ScreenDescriptor(
                    id: old.id, frame: old.frame,
                    visibleFrame: CGRect(x: 0, y: 0, width: 1470, height: 50), backingScale: 2, isPrimary: true)
            ]))
        world.tuning.activityWeights = [.jump: 1]
        let first = world.step(dt: Self.dt)
        #expect(first.contains(.jumpRejected(world.pets[0].id, .unreachable)))
        #expect(world.pets[0].state == .grounded(.idle))
        let count = world.pets[0].activityDecisionCount
        Self.advance(&world, seconds: 1.9)
        #expect(world.pets[0].activityDecisionCount == count)
    }

    @Test func walkingWithoutProgressGetsBoundedIdle() throws {
        var world = try Self.world()
        world.tuning.fallbackWalkSpeed = 0
        world.tuning.activityWeights = [.walk: 1]
        // This fixture has a nominal walk speed; a zero-duration surface range provides no progress.
        let narrow = Surface(id: .dock, kind: .dockTop, y: 0, minX: 552, maxX: 648)
        world.apply(.surfaces([narrow]))
        PetWorldTests.set(&world, x: 600, facing: .right)
        Self.advance(&world, seconds: 2.2)
        #expect(world.pets[0].state == .grounded(.idle))
        #expect(world.pets[0].activityDeadline >= world.time + 1.7)
    }

    @Test func resizeUpdatesContactAndSpriteAndCancelsPreparationWithoutMovingFoot() throws {
        var world = try JumpWorldTests.world()
        let id = world.pets[0].id
        world.apply(.requestJump(id, JumpRequest()))
        let foot = world.pets[0].position
        let facing = world.pets[0].facing
        let halfWidth = try #require(world.pets[0].contactGeometry).halfWidth
        world.apply(.setDisplayScale(1.5))
        #expect(world.pets[0].position == foot)
        #expect(world.pets[0].facing == facing)
        #expect(world.pets[0].size.width == 144)
        #expect(world.pets[0].contactGeometry?.halfWidth == halfWidth * 1.5)
        #expect(world.pets[0].state != .grounded(.preparingJump))
        world.apply(.setDisplayScale(.nan))
        world.apply(.setSpeedScale(.infinity))
        #expect(world.pets[0].size.width.isFinite)
        #expect(world.tuning.speedScale == 1)
        #expect(world.step(dt: Self.dt).contains(.jumpCancelled(id)))
    }

    @Test func defaultWorldPreservesExplicitCommandPolicy() throws {
        var world = try PetWorldTests.makeWorld().world
        #expect(!world.behavior.isEnabled)
        Self.advance(&world, seconds: 100)
        #expect(world.pets[0].activityDecisionCount == 0)
    }

    @Test(arguments: [1, 8, 32])
    func seededReplayIsIndependentOfArtFrames(frameCount: Int) throws {
        var fallback = try Self.world()
        var authored = PetWorld(random: SeededRandomSource(seed: 42))
        authored.apply(.screens([PetWorldTests.screen]))
        authored.apply(.surfaces([PetWorldTests.floor]))
        authored.spawn(try JumpAnimationTests.definition(frameCount: frameCount))
        PetWorldTests.set(&authored, x: 600, facing: .right)
        authored.apply(.configureBehavior(AutonomySettings()))
        for _ in 0..<12_000 {
            _ = fallback.step(dt: Self.dt)
            _ = authored.step(dt: Self.dt)
            #expect(fallback.pets[0].position == authored.pets[0].position)
            #expect(fallback.pets[0].state == authored.pets[0].state)
            #expect(fallback.pets[0].activity == authored.pets[0].activity)
            #expect(fallback.pets[0].needs == authored.pets[0].needs)
        }
    }
    @Test func sleepingAuthoredLowFPSDoesNotStopLogicalDeadline() throws {
        var manifest = try Fixtures.manifest("valid-cat")
        manifest.displaySize = .init(width: 96, height: 96)
        manifest.animations["sleep"] = .init(fps: 2, frames: [.init(image: "sleep.png")])
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        var world = PetWorld(random: SeededRandomSource(seed: 42))
        world.apply(.screens([PetWorldTests.screen]))
        world.apply(.surfaces([PetWorldTests.floor]))
        world.spawn(definition)
        world.pets[0].needs = Needs(energy: 0.05)
        world.apply(.configureBehavior(AutonomySettings()))
        Self.advance(&world, seconds: 1)
        #expect(world.pets[0].state == .grounded(.sleeping))
        #expect(world.preferredFramesPerSecond == 2)
        #expect(world.needsSimulationSteps)
        let deadline = world.pets[0].activityDeadline
        while world.time + Self.dt < deadline { _ = world.step(dt: Self.dt) }
        Self.advance(&world, seconds: 0.6)
        #expect(world.pets[0].state == .grounded(.idle))
    }

    @Test(arguments: [Activity.sit, .sleep, .stretch, .observe, .explore])
    func eachActivityCompletesWithMissingArt(activity: Activity) throws {
        var world = try Self.world(energy: activity == .sleep ? 0.2 : 0.7)
        world.tuning.activityWeights = [activity: 1]
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].activity == activity)
        let firstCount = world.pets[0].activityDecisionCount
        let maximum = activity.duration.upperBound + 1.5
        Self.advance(&world, seconds: maximum)
        #expect(world.pets[0].activityDecisionCount > firstCount || world.pets[0].state == .grounded(.idle))
        #expect(world.pets[0].attachment != nil)
        #expect(world.pets[0].position.x.isFinite)
    }

    @Test func sleepCooldownRemainsUnavailableUntilSimulatedDeadline() throws {
        var world = try Self.world(energy: 0.2)
        world.tuning.activityWeights = [.sleep: 1]
        _ = world.step(dt: Self.dt)
        Self.advance(&world, seconds: 0.5)
        world.apply(.wake(world.pets[0].id))
        Self.advance(&world, seconds: 2.6)
        #expect(world.pets[0].activity == .idle)
        #expect((world.pets[0].activityCooldowns[.sleep] ?? 0) > world.time)
        let cooldown = try #require(world.pets[0].activityCooldowns[.sleep])
        // Eligibility changes at the cooldown; choice waits until the current bounded idle ends.
        while world.time < cooldown + Activity.idle.duration.upperBound + Self.dt {
            _ = world.step(dt: Self.dt)
        }
        #expect(world.pets[0].activity == .sleep)
    }

    @Test func policyDisablesOnlyAutomaticJumpsAndPreservesExplicitJumpCommands() throws {
        var world = try Self.world()
        world.apply(
            .configureBehavior(AutonomySettings(jumpsEnabled: false, restEnabled: false, expressionsEnabled: false)))
        world.tuning.activityWeights = [.jump: 1, .sit: 1, .sleep: 1, .stretch: 1, .observe: 1]
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].activity == .idle)
        world.apply(.requestJump(world.pets[0].id, JumpRequest(returnActivity: .idle)))
        #expect(world.pets[0].state == .grounded(.preparingJump))
        Self.advance(&world, seconds: 1)
        #expect(world.pets[0].activityDecisionCount == 1)
    }

    @Test func disablingJumpsCancelsOnlyAnAutonomousPreparation() throws {
        var autonomous = try Self.world()
        autonomous.tuning.activityWeights = [.jump: 1]
        _ = autonomous.step(dt: Self.dt)
        #expect(autonomous.pets[0].state == .grounded(.preparingJump))
        autonomous.apply(.configureBehavior(AutonomySettings(jumpsEnabled: false)))
        #expect(autonomous.pets[0].state == .grounded(.idle))
        let events = autonomous.step(dt: Self.dt)
        #expect(events.contains(.jumpCancelled(autonomous.pets[0].id)))
        var explicit = try JumpWorldTests.world()
        explicit.apply(.requestJump(explicit.pets[0].id, JumpRequest()))
        explicit.apply(.configureBehavior(AutonomySettings(jumpsEnabled: false)))
        #expect(explicit.pets[0].state == .grounded(.preparingJump))
    }

    @Test func exceptionalRecoveryEndsInterruptedActivityBeforeNextChoice() throws {
        var world = try Self.world(energy: 0.05)
        Self.advance(&world, seconds: 1)
        let decisions = world.pets[0].activityDecisionCount
        world.pets[0].position.x = .nan
        _ = world.step(dt: Self.dt)
        #expect(world.pets[0].activity == nil)
        Self.advance(&world, seconds: 0.7)
        #expect(world.pets[0].activityDecisionCount > decisions)
        #expect(world.pets[0].position.x.isFinite)
    }

    @Test(arguments: [PetStateKind.rising, .falling, .landing], [false, true])
    func autonomyDisableDuringJumpRecordsCooldownWithoutChangingPhysics(
        phase: PetStateKind, reenableBeforeLanding: Bool
    ) throws {
        var world = try Self.world()
        world.tuning.activityWeights = [.jump: 1]
        let id = world.pets[0].id
        for _ in 0..<130 {
            _ = world.step(dt: Self.dt)
            if world.pets[0].state.kind == phase { break }
        }
        try #require(world.pets[0].state.kind == phase)
        let before = world.pets[0]
        let cancelledAt = world.time
        let deadline = cancelledAt + 8
        world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
        #expect(world.pets[0].position == before.position)
        #expect(world.pets[0].velocity == before.velocity)
        #expect(world.pets[0].state == before.state)
        #expect(world.pets[0].stateElapsed == before.stateElapsed)
        #expect(world.pets[0].activityCooldowns[.jump] == deadline)
        // Reapplying an unchanged setting must not restart an already recorded cooldown.
        world.apply(.configureBehavior(AutonomySettings(isEnabled: false)))
        #expect(world.pets[0].activityCooldowns[.jump] == deadline)
        if reenableBeforeLanding {
            world.apply(.configureBehavior(AutonomySettings()))
            #expect(world.pets[0].position == before.position)
            #expect(world.pets[0].velocity == before.velocity)
            #expect(world.pets[0].state == before.state)
        }
        var landed = phase == .landing
        for _ in 0..<130 {
            let events = world.step(dt: Self.dt)
            #expect(!events.contains(.tookOff(id)))
            landed = landed || events.contains(.landed(id, PetWorldTests.floor.id))
            if world.pets[0].state == .grounded(.idle) { break }
        }
        #expect(landed)
        try #require(world.pets[0].state == .grounded(.idle))
        #expect(world.pets[0].activityCooldowns[.jump] == deadline)
        if !reenableBeforeLanding {
            // Stay disabled beyond M8's separate 2-second launch cooldown. Only M9's automatic
            // cooldown can prevent an early new jump after this re-enable.
            while world.time < cancelledAt + 3 { _ = world.step(dt: Self.dt) }
            let settled = world.pets[0]
            world.apply(.configureBehavior(AutonomySettings()))
            #expect(world.pets[0].position == settled.position)
            #expect(world.pets[0].velocity == settled.velocity)
            #expect(world.pets[0].state == settled.state)
        }
        while world.time + Self.dt < deadline {
            let events = world.step(dt: Self.dt)
            #expect(!events.contains(.tookOff(id)))
        }
        var nextTakeoff: Double?
        while world.time < deadline + Activity.idle.duration.upperBound + 0.5 {
            let events = world.step(dt: Self.dt)
            if events.contains(.tookOff(id)) {
                nextTakeoff = world.time
                break
            }
        }
        let launchedAt = try #require(nextTakeoff)
        #expect(launchedAt >= deadline)
    }

}
