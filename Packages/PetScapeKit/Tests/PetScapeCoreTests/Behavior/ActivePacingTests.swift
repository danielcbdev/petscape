import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("Owner tuning — active pacing")
struct ActivePacingTests {
    @Test(arguments: [Activity.idle, .sit, .sleep, .observe, .stretch])
    func autonomousStopsNeverExceedFiveSeconds(activity: Activity) throws {
        var world = try AutonomyTests.world()
        world.tuning.activityWeights = [activity: 1]
        world.apply(.configureBehavior(AutonomySettings(jumpsEnabled: false)))
        var stopped = 0.0
        var longestStop = 0.0
        var sawStop = false
        for _ in 0..<7200 {
            _ = world.step(dt: AutonomyTests.dt)
            let pet = world.pets[0]
            if pet.state == .walking {
                stopped = 0
            } else {
                stopped += AutonomyTests.dt
                longestStop = max(longestStop, stopped)
                sawStop = true
            }
        }
        #expect(sawStop)
        #expect(longestStop <= 5 + AutonomyTests.dt + 0.000_001, "\(activity): \(longestStop) s")
    }

    @Test(arguments: [UInt64(1), 42, 85])
    func defaultPolicySpendsAtLeastEightyPercentOfTimeMoving(seed: UInt64) throws {
        var world = try AutonomyTests.world(seed: seed)
        world.apply(.configureBehavior(AutonomySettings(jumpsEnabled: false)))
        var moving = 0
        let steps = 36_000
        for _ in 0..<steps {
            _ = world.step(dt: AutonomyTests.dt)
            if world.pets[0].state == .walking { moving += 1 }
        }
        #expect(Double(moving) / Double(steps) >= 0.8)
    }

    @Test func autonomousLandingStartsAWalkBeforeChoosingAnotherRest() throws {
        var world = try AutonomyTests.world()
        world.tuning.activityWeights = [.idle: 1]
        world.pets[0].state = .grounded(.landing)
        world.pets[0].activity = nil
        world.pets[0].resumeActivity = .walking
        AutonomyTests.advance(&world, seconds: 0.3)
        #expect(world.pets[0].state == .walking)
        #expect(world.pets[0].activity == .walk)
        #expect(world.pets[0].activityDeadline > world.time + 7)
    }

    @Test func automaticJumpReturnsToWalking() throws {
        var world = try AutonomyTests.world()
        world.tuning.activityWeights = [.jump: 1]
        AutonomyTests.advance(&world, seconds: 0.1)
        #expect(world.pets[0].state == .grounded(.preparingJump))
        #expect(world.pets[0].resumeActivity == .walking)
        var landed = false
        for _ in 0..<300 {
            let events = world.step(dt: AutonomyTests.dt)
            if events.contains(where: { if case .landed = $0 { true } else { false } }) { landed = true }
            if landed, world.pets[0].state == .walking { break }
        }
        #expect(landed)
        #expect(world.pets[0].activity == .walk)
    }

    @Test func expandedSpeedRangeKeepsGroundAndAnimationRatesTogether() throws {
        #expect(PetSettings(speed: 4).speed == 4)
        #expect(PetSettings(speed: 9).speed == 4)
        var world = try PetWorldTests.makeWorld(nominalSpeed: 13.5).world
        PetWorldTests.set(&world, x: 600, facing: .right)
        world.apply(.setSpeedScale(4))
        AutonomyTests.advance(&world, seconds: 1)
        #expect(abs(world.pets[0].position.x - 654) < 0.000_001)
        #expect(world.pets[0].animation.rate == 4)
    }
}
