import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("M13 autonomous window climbing")
struct WindowClimbTests {
    static let dt = 1.0 / 60
    static let screen = ScreenDescriptor(
        id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 930), backingScale: 2, isPrimary: true)

    @Test func solverTargetsTheVisibleSideBelowItsTop() throws {
        let dock = Surface(id: .dock, kind: .dockTop, y: 0, minX: 0, maxX: 1470)
        let side = Surface(
            id: SurfaceID("window:42:left:window:42:bottom:window:42:top"),
            kind: .windowLeft, x: 700, minY: 100, maxY: 400)
        let top = Surface(
            id: SurfaceID("window:42:top:window:42:left:window:42:right"), kind: .windowTop, y: 400, minX: 700,
            maxX: 1000)
        let map = SurfaceMap([dock, side, top])
        let geometry = try #require(ContactGeometry(displaySize: CGSize(width: 96, height: 64), scale: 1))

        let plan = try #require(
            WindowClimbSolver.solve(
                from: CGPoint(x: 660, y: 0), target: side, targetY: 180, surfaces: map,
                geometry: geometry, screen: Self.screen, physics: PhysicsTuning(), tuning: JumpTuning(),
                visualMargin: 48))

        #expect(plan.target == side)
        #expect(plan.contactPosition.x == side.minX)
        #expect(plan.contactPosition.y < side.maxY - 24)
        #expect(plan.initialVelocity.dy > 0)
    }

    @Test func autonomousExcursionClimbsTheSideThenReturnsToDock() throws {
        let windowID = "window:42"
        let dock = Surface(id: .dock, kind: .dockTop, y: 0, minX: 0, maxX: 1470)
        let side = Surface(
            id: SurfaceID("\(windowID):left:window:42:bottom:window:42:top"),
            kind: .windowLeft, x: 700, minY: 100, maxY: 400)
        let top = Surface(
            id: SurfaceID("\(windowID):top:window:42:left:window:42:right"), kind: .windowTop, y: 400, minX: 700,
            maxX: 1000)
        var world = PetWorld(
            tuning: BehaviorTuning(activityWeights: [.windowExcursion: 1]), random: SeededRandomSource(seed: 42))
        world.apply(.screens([Self.screen]))
        world.apply(.surfaces([dock, side, top]))
        let petID = world.spawn(try Fixtures.walkingDefinition(nominalSpeed: 20))
        // The cat starts underneath the window's span, the common Dock position that previously
        // filtered out both sides before it could walk to a jump launch point.
        PetWorldTests.set(&world, x: 850, facing: .right)
        world.apply(.configureBehavior(AutonomySettings()))

        var events: [WorldEvent] = []
        var sideContactY: CGFloat?
        var topWalkDuration: Double?
        for _ in 0..<3600 {
            let eventStart = events.count
            world.step(dt: Self.dt, into: &events)
            if sideContactY == nil, events[eventStart...].contains(.landed(petID, side.id)) {
                sideContactY = world.pet(petID)?.position.y
            }
            if topWalkDuration == nil, events[eventStart...].contains(.landed(petID, top.id)) {
                topWalkDuration = world.pet(petID)?.activityDuration
            }
        }

        #expect(events.contains(.landed(petID, side.id)))
        #expect(try #require(sideContactY) < 240)
        #expect(events.contains(.stateChanged(petID, from: .falling, to: .climbing)))
        #expect(events.contains(.landed(petID, top.id)))
        let duration = try #require(topWalkDuration)
        #expect(duration >= 7 && duration < 19)
        #expect(events.contains(.landed(petID, dock.id)))
        #expect(world.pet(petID)?.attachment?.surfaceID == dock.id)
    }

    @Test func defaultAutonomyChoosesJumpsAndWindowExcursionsAcrossSeeds() throws {
        let dock = Surface(id: .dock, kind: .dockTop, y: 0, minX: 0, maxX: 1470)
        let side = Surface(
            id: SurfaceID("window:42:left:window:42:bottom:window:42:top"),
            kind: .windowLeft, x: 700, minY: 100, maxY: 400)
        let top = Surface(
            id: SurfaceID("window:42:top:window:42:left:window:42:right"),
            kind: .windowTop, y: 400, minX: 700, maxX: 1000)
        let definition = try Fixtures.walkingDefinition(nominalSpeed: 20)
        var choices: [Activity] = []
        var previousPolicyChoices: [Activity] = []
        let previousWeights: [Activity: Double] = [
            .walk: 4, .idle: 0.1, .jump: 0.7, .sit: 0.075, .sleep: 0,
            .stretch: 0.15, .observe: 0.15, .explore: 0.8, .windowExcursion: 0.6,
        ]
        let previousCandidates = Activity.allCases.map {
            ActivityCandidate($0, weight: previousWeights[$0] ?? 0)
        }

        for seed in 1...256 {
            var world = PetWorld(random: SeededRandomSource(seed: UInt64(seed)))
            world.apply(.screens([Self.screen]))
            world.apply(.surfaces([dock, side, top]))
            let petID = world.spawn(definition)
            PetWorldTests.set(&world, x: 660, facing: .right)
            world.apply(.configureBehavior(AutonomySettings()))
            var previousRandom = try #require(world.pet(petID)?.random)
            previousPolicyChoices.append(
                ActivitySelector.select(
                    previousCandidates, previous: nil, repetitions: 0, random: &previousRandom))
            _ = world.step(dt: Self.dt)
            if let activity = world.pet(petID)?.previousActivity {
                choices.append(activity)
            }
        }

        #expect(choices.count == 256)
        #expect(previousPolicyChoices.count == choices.count)
        #expect(choices.filter { $0 == .jump }.count > previousPolicyChoices.filter { $0 == .jump }.count)
        #expect(
            choices.filter { $0 == .windowExcursion }.count
                > previousPolicyChoices.filter { $0 == .windowExcursion }.count)
        #expect(Activity.windowExcursion.cooldown == 20)
    }

    @Test func multipleEligibleWindowsAreChosenRandomly() throws {
        let windows: [(Surface, Surface)] = [
            (
                Surface(
                    id: SurfaceID("window:42:left:window:42:bottom:window:42:top"),
                    kind: .windowLeft, x: 700, minY: 100, maxY: 400),
                Surface(
                    id: SurfaceID("window:42:top:window:42:left:window:42:right"),
                    kind: .windowTop, y: 400, minX: 700, maxX: 1000)
            ),
            (
                Surface(
                    id: SurfaceID("window:43:left:window:43:bottom:window:43:top"),
                    kind: .windowLeft, x: 900, minY: 100, maxY: 400),
                Surface(
                    id: SurfaceID("window:43:top:window:43:left:window:43:right"),
                    kind: .windowTop, y: 400, minX: 900, maxX: 1200)
            ),
        ]
        var selected: Set<String> = []
        for seed in 1...12 {
            let dock = Surface(id: .dock, kind: .dockTop, y: 0, minX: 0, maxX: 1470)
            var world = PetWorld(
                tuning: BehaviorTuning(activityWeights: [.windowExcursion: 1]),
                random: SeededRandomSource(seed: UInt64(seed)))
            world.apply(.screens([Self.screen]))
            world.apply(.surfaces([dock] + windows.flatMap { [$0.0, $0.1] }))
            _ = world.spawn(try Fixtures.walkingDefinition(nominalSpeed: 20))
            PetWorldTests.set(&world, x: 660, facing: .right)
            world.apply(.configureBehavior(AutonomySettings()))
            _ = world.step(dt: Self.dt)
            let phase = try #require(world.pets[0].windowExcursionPhase)
            switch phase {
            case .approachingWindowSide(let id), .jumpingToSide(let id):
                selected.insert(String(id.rawValue.split(separator: ":")[1]))
            default:
                Issue.record("Expected the autonomous action to select a window side")
            }
        }

        #expect(selected == ["42", "43"])
    }
}
