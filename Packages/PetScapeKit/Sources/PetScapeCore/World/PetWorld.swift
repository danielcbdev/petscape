import CoreGraphics
import Foundation

/// The simulation: pets, surfaces and screens, advanced in fixed steps (pet-engine.md, ADR-0013).
///
/// A value type with no clock and no outside calls: the runtime feeds environment changes with `apply(_:)`,
/// advances it with `step(dt:into:)` and draws `snapshot()`. Randomness is injected, so a seeded world is fully
/// deterministic.
///
/// Step order per pet (pet-engine.md#step-order, MVP subset): behavior (state machine) → motion along the
/// attached surface → edge detection → animation → validation and recovery. Environment changes are applied
/// before the step by `apply(_:)`.
public struct PetWorld: Sendable {
    public internal(set) var pets: [Pet] = []
    public private(set) var surfaces = SurfaceMap()
    public private(set) var screens: [ScreenDescriptor] = []
    /// Simulation time in seconds (sum of all step `dt`s).
    public private(set) var time: Double = 0
    public private(set) var behavior = AutonomySettings(isEnabled: false)
    public var tuning: BehaviorTuning
    var physics = PhysicsTuning()
    var jumpTuning = JumpTuning()
    private var pendingEvents: [WorldEvent] = []

    private var random: any RandomSource
    private var nextPetID = 1
    /// Reused per step so stepping does not allocate.
    private var animationEvents: [AnimationEvent] = []

    public init(tuning: BehaviorTuning = BehaviorTuning(), random: any RandomSource) {
        self.tuning = tuning
        self.random = random
        animationEvents.reserveCapacity(8)
        pendingEvents.reserveCapacity(16)
    }

    public func pet(_ id: PetID) -> Pet? {
        pets.first { $0.id == id }
    }

    // MARK: - Lifecycle

    /// Adds a pet of `definition` and places it right away when a surface exists (random position and facing,
    /// walk clip at frame 0); otherwise it stays `spawning` until a surface appears.
    @discardableResult
    public mutating func spawn(_ definition: CharacterDefinition, scale: Double = 1) -> PetID {
        let id = PetID(nextPetID)
        nextPetID += 1
        var pet = Pet(id: id, definition: definition, scale: scale)
        pet.animation.rate = tuning.speedScale
        var events: [WorldEvent] = []
        place(&pet, events: &events)
        pets.append(pet)
        return id
    }

    public mutating func removeAllPets() {
        pets.removeAll()
        pendingEvents.removeAll(keepingCapacity: true)
    }

    // MARK: - Environment

    /// Applies an environment change now (between steps). Attached pets are re-projected onto moved surfaces
    /// by their parameter and kept inside the walkable range; pets whose support disappeared detach and fall
    /// on their next step; unplaced pets are placed when a surface appears.
    public mutating func apply(_ input: WorldInput) {
        switch input {
        case .configureBehavior(let settings):
            behavior = settings
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if (!settings.isEnabled || !settings.jumpsEnabled), pet.activity == .jump,
                    pet.state == .grounded(.preparingJump)
                {
                    cancelJump(&pet, events: &events)
                    boundedIdle(&pet, events: &events)
                }
                if !settings.isEnabled || !settings.restEnabled {
                    switch pet.state {
                    case .grounded(.sleeping), .grounded(.lyingDown):
                        finishActivity(&pet)
                        enter(.grounded(.wakingUp), pet: &pet, events: &events)
                    case .grounded(.sittingDown), .grounded(.sitting):
                        finishActivity(&pet)
                        enter(.grounded(.standingUp), pet: &pet, events: &events)
                    default: break
                    }
                }
                if !settings.isEnabled
                    || (!settings.expressionsEnabled && (pet.activity == .stretch || pet.activity == .observe))
                {
                    if pet.state == .grounded(.stretching) || pet.state == .grounded(.observing) {
                        boundedIdle(&pet, events: &events)
                    }
                    // Cancel the autonomous activity, not its physical flight. This records its
                    // cooldown once at the simulated cancellation time, including Rising/Landing.
                    finishActivity(&pet)
                }
                pets[index] = pet
            }
            pendingEvents.append(contentsOf: events)
        case .setDisplayScale(let value):
            let scale = PetSettings.displayScale(value)
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                guard pet.scale != scale else { continue }
                pet.scale = scale
                let size = pet.animation.definition.displaySize
                pet.contactGeometry = ContactGeometry(
                    displaySize: CGSize(width: size.width, height: size.height), scale: scale)
                cancelJump(&pet, events: &events)
                // Keep the canonical foot fixed whenever it still fits; only clamp at a support edge.
                if let attachment = pet.attachment, let surface = surfaces.surface(attachment.surfaceID),
                    surface.isUsable
                {
                    let range = surface.walkableRange(margin: pet.edgeMargin)
                    let x = min(max(pet.position.x, range.lowerBound), range.upperBound)
                    if x.isFinite { setPosition(of: &pet, x: x, on: surface) }
                }
                pets[index] = pet
            }
            pendingEvents.append(contentsOf: events)
        case .setSpeedScale(let value):
            tuning.speedScale = PetSettings.speedScale(value)
            for index in pets.indices where pets[index].state == .walking {
                pets[index].animation.rate = tuning.speedScale
            }
        case .wake(let id):
            guard let index = pets.firstIndex(where: { $0.id == id }) else { return }
            var pet = pets[index]
            switch pet.state {
            case .grounded(.sleeping), .grounded(.lyingDown):
                var events: [WorldEvent] = []
                finishActivity(&pet)
                enter(.grounded(.wakingUp), pet: &pet, events: &events)
                pets[index] = pet
                pendingEvents.append(contentsOf: events)
            default: break
            }
        case .screens(let screens):
            let old = self.screens.first
            self.screens = screens
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if let old, let next = screens.first, old.id != next.id {
                    recover(&pet, reason: .outOfBounds, events: &events)
                } else if old?.frame != screens.first?.frame {
                    cancelJump(&pet, events: &events)
                }
                pets[index] = pet
            }
            pendingEvents.append(contentsOf: events)
        case .surfaces(let newSurfaces):
            let changes = surfaces.changes(to: newSurfaces)
            guard !changes.isEmpty else { return }
            surfaces.apply(changes)
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if pet.attachment == nil {
                    if pet.state == .spawning { place(&pet, events: &events) }
                } else if let attachment = pet.attachment,
                    changes.contains(where: {
                        if case .moved(let surface) = $0 { surface.id == attachment.surfaceID } else { false }
                    })
                {
                    reproject(&pet)
                }
                if let plan = pet.jumpPlan,
                    surfaces.surface(plan.target.id) != plan.target
                        || pet.jumpSource.map({ surfaces.surface($0.id) != $0 }) == true
                {
                    cancelJump(&pet, events: &events)
                }
                pets[index] = pet
            }
            pendingEvents.append(contentsOf: events)
        case .requestJump(let id, let request):
            guard let index = pets.firstIndex(where: { $0.id == id }) else {
                pendingEvents.append(.jumpRejected(id, .unknownPet))
                return
            }
            var pet = pets[index]
            var events: [WorldEvent] = []
            requestJump(request, pet: &pet, events: &events)
            pets[index] = pet
            pendingEvents.append(contentsOf: events)
        case .setActivity(let id, let activity):
            guard let index = pets.firstIndex(where: { $0.id == id }),
                pets[index].state == .walking || pets[index].state == .grounded(.idle),
                attachedSurface(of: pets[index]) != nil
            else { return }
            var pet = pets[index]
            var events: [WorldEvent] = []
            pet.resumeActivity = activity
            enter(activity == .walking ? .walking : .grounded(.idle), pet: &pet, events: &events)
            pets[index] = pet
            pendingEvents.append(contentsOf: events)
        }
    }

    /// Environment/command events can be logged even when the resulting pose requires no frames.
    public mutating func drainEvents(into events: inout [WorldEvent]) {
        events.append(contentsOf: pendingEvents)
        pendingEvents.removeAll(keepingCapacity: true)
    }

    // MARK: - Step

    /// Advances every pet by one fixed step and appends what happened to `events` (not cleared first).
    public mutating func step(dt: Double, into events: inout [WorldEvent]) {
        guard dt.isFinite, dt > 0,
            dt <= FixedStepAccumulator.defaultStep + FixedStepAccumulator.tolerance
        else { return }
        let dt =
            abs(dt - FixedStepAccumulator.defaultStep) <= FixedStepAccumulator.tolerance
            ? FixedStepAccumulator.defaultStep : dt
        time += dt
        drainEvents(into: &events)
        for index in pets.indices {
            // Stepped on a copy: the step also mutates other world state (random source, event buffer).
            var pet = pets[index]
            step(&pet, dt: dt, events: &events)
            pets[index] = pet
        }
    }

    /// Convenience for tests and non-hot paths.
    public mutating func step(dt: Double) -> [WorldEvent] {
        var events: [WorldEvent] = []
        step(dt: dt, into: &events)
        return events
    }

    private mutating func step(_ pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        guard validate(&pet, events: &events) else { return }
        pet.stateElapsed += dt
        if behavior.isEnabled {
            pet.needs.advance(by: dt, sleeping: pet.state == .grounded(.sleeping))
        }
        if let attachment = pet.attachment, attachedSurface(of: pet) == nil {
            pet.attachment = nil
            pet.airborneElapsed = 0
            finishActivity(&pet)
            enter(.airborne(.falling), pet: &pet, events: &events)
            events.append(.surfaceLost(pet.id, attachment.surfaceID))
        }
        if behavior.isEnabled, attachedSurface(of: pet) != nil,
            pet.state == .walking || pet.state == .grounded(.idle),
            pet.activity == nil || time + FixedStepAccumulator.tolerance >= pet.activityDeadline
        {
            chooseActivity(&pet, events: &events)
        }
        switch pet.state {
        case .spawning:
            if pet.attachment == nil { place(&pet, events: &events) }
            if pet.attachment != nil { enter(.walking, pet: &pet, events: &events) }
        case .grounded(let state):
            guard let surface = attachedSurface(of: pet) else {
                pet.airborneElapsed = 0
                enter(.airborne(.falling), pet: &pet, events: &events)
                fall(&pet, dt: dt, events: &events)
                return
            }
            switch state {
            case .walking:
                let nominal =
                    pet.animation.definition.clip(named: BehaviorTuning.walkClip).nominalSpeed
                    ?? tuning.fallbackWalkSpeed
                let speed = nominal * tuning.speedScale * pet.scale
                guard
                    let result = PhysicsStepper.attached(
                        position: pet.position, on: surface, margin: pet.edgeMargin,
                        intent: .walk(speed: speed, facing: pet.facing), dt: dt)
                else { return recover(&pet, reason: .invalidNumbers, events: &events) }
                commit(result, to: &pet)
                pet.animation.rate = tuning.speedScale
                advanceAnimation(of: &pet, dt: dt, events: &events)
                if behavior.isEnabled, pet.activity == .walk || pet.activity == .explore {
                    if abs(pet.position.x - pet.progressPosition.x) > 0.01 {
                        pet.noProgressElapsed = 0
                        pet.progressPosition = pet.position
                    } else {
                        pet.noProgressElapsed += dt
                    }
                    if pet.noProgressElapsed + FixedStepAccumulator.tolerance >= 2 {
                        boundedIdle(&pet, events: &events)
                    }
                }
                if result.edgeReached, pet.state == .walking {
                    events.append(.edgeReached(pet.id))
                    enter(.turning(to: pet.facing.opposite), pet: &pet, events: &events)
                }
            case .turning(let newFacing):
                pet.velocity = .zero
                if behavior.isEnabled { pet.noProgressElapsed += dt }
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= tuning.turnHold {
                    pet.facing = newFacing
                    pet.animation.setFacing(newFacing)
                    enter(.walking, pet: &pet, events: &events)
                }
            case .landing:
                pet.velocity = .zero
                advancePresentation(of: &pet, dt: dt, events: &events)
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= jumpTuning.landingDuration {
                    enter(pet.resumeActivity == .walking ? .walking : .grounded(.idle), pet: &pet, events: &events)
                    if pet.activity == .jump { finishActivity(&pet) }
                }
            case .idle:
                pet.velocity = .zero
                advancePresentation(of: &pet, dt: dt, events: &events)
            case .sittingDown:
                hold(&pet, dt: dt, events: &events)
                if elapsed(pet, atLeast: 0.3) {
                    enter(.grounded(.sitting), pet: &pet, events: &events)
                    pet.activityDeadline = time + pet.activityDuration
                }
            case .lyingDown:
                hold(&pet, dt: dt, events: &events)
                if elapsed(pet, atLeast: 0.3) {
                    enter(.grounded(.sleeping), pet: &pet, events: &events)
                    pet.activityDeadline = time + pet.activityDuration
                }
            case .sitting:
                hold(&pet, dt: dt, events: &events)
                if time + FixedStepAccumulator.tolerance >= pet.activityDeadline {
                    finishActivity(&pet)
                    enter(.grounded(.standingUp), pet: &pet, events: &events)
                }
            case .sleeping:
                hold(&pet, dt: dt, events: &events)
                if time + FixedStepAccumulator.tolerance >= pet.activityDeadline {
                    finishActivity(&pet)
                    enter(.grounded(.wakingUp), pet: &pet, events: &events)
                }
            case .standingUp, .wakingUp:
                hold(&pet, dt: dt, events: &events)
                if elapsed(pet, atLeast: state == .wakingUp ? 0.5 : 0.3) {
                    boundedIdle(&pet, events: &events)
                }
            case .stretching, .observing:
                hold(&pet, dt: dt, events: &events)
                if time + FixedStepAccumulator.tolerance >= pet.activityDeadline {
                    boundedIdle(&pet, events: &events)
                }
            case .preparingJump:
                pet.velocity = .zero
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= jumpTuning.preparationDuration {
                    guard let plan = pet.jumpPlan, pet.jumpRequestID > pet.consumedJumpID,
                        pet.jumpSource == surface, surfaces.surface(plan.target.id) == plan.target,
                        let geometry = pet.contactGeometry, let screen = screens.first,
                        JumpSolver.solve(
                            from: pet.position, target: plan.requestedTarget, targetSurfaceID: plan.target.id,
                            surfaces: surfaces, geometry: geometry, screen: screen, physics: physics,
                            tuning: jumpTuning, visualMargin: pet.edgeMargin) == plan
                    else {
                        cancelJump(&pet, events: &events)
                        return
                    }
                    pet.consumedJumpID = pet.jumpRequestID
                    pet.lastJumpLaunchTime = time
                    pet.attachment = nil
                    pet.velocity = plan.initialVelocity
                    pet.airborneElapsed = 0
                    enter(.airborne(.rising), pet: &pet, events: &events)
                    events.append(.tookOff(pet.id))
                    fall(&pet, dt: dt, events: &events)
                } else {
                    advancePresentation(of: &pet, dt: dt, events: &events)
                }
            }
        case .airborne:
            fall(&pet, dt: dt, events: &events)
        case .recovering:
            enter(.spawning, pet: &pet, events: &events)
            if !resettle(&pet, events: &events) { place(&pet, events: &events) }
        }
        _ = validate(&pet, events: &events)
    }

    private func visualRange(for pet: Pet) -> ClosedRange<CGFloat> {
        guard let screen = screens.first else {
            return -CGFloat.greatestFiniteMagnitude...CGFloat.greatestFiniteMagnitude
        }
        let lower = screen.frame.minX + pet.edgeMargin
        let upper = screen.frame.maxX - pet.edgeMargin
        return lower <= upper ? lower...upper : screen.frame.midX...screen.frame.midX
    }

    private mutating func fall(_ pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        pet.airborneElapsed += dt
        guard pet.airborneElapsed <= physics.maxAirborneDuration + FixedStepAccumulator.tolerance else {
            return recover(&pet, reason: .airborneTimeout, events: &events)
        }
        guard let geometry = pet.contactGeometry,
            let result = PhysicsStepper.airborne(
                position: pet.position, velocity: pet.velocity, acceleration: .zero, dt: dt,
                tuning: physics, surfaces: surfaces, geometry: geometry, visualRange: visualRange(for: pet))
        else { return recover(&pet, reason: .invalidNumbers, events: &events) }
        let wasRising = pet.state == .airborne(.rising)
        commit(result, to: &pet)
        if wasRising && result.velocity.dy <= 0 {
            events.append(.apex(pet.id))
            enter(.airborne(.falling), pet: &pet, events: &events)
        }
        if let surfaceID = result.landedSurfaceID {
            pet.jumpPlan = nil
            pet.jumpSource = nil
            events.append(.landed(pet.id, surfaceID))
            enter(.grounded(.landing), pet: &pet, events: &events)
        }
        advancePresentation(of: &pet, dt: dt, events: &events)
    }

    private func commit(_ result: PhysicsStepResult, to pet: inout Pet) {
        pet.position = result.position
        pet.velocity = result.velocity
        pet.attachment = result.attachment
    }

    /// Missing phase art holds a safe default pose, but never stops simulation timers.
    private mutating func advancePresentation(of pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        guard pet.animation.definition.clips[pet.animation.requestedClip] != nil else { return }
        animationEvents.removeAll(keepingCapacity: true)
        pet.animation.advancePhase(by: dt, into: &animationEvents)
        for event in animationEvents { events.append(.animationEvent(pet.id, event)) }
    }

    private mutating func advanceAnimation(of pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        animationEvents.removeAll(keepingCapacity: true)
        pet.animation.advance(by: dt, into: &animationEvents)
        for event in animationEvents {
            events.append(.animationEvent(pet.id, event))
        }
    }

    // MARK: - Autonomous activity boundaries

    private func elapsed(_ pet: Pet, atLeast duration: Double) -> Bool {
        pet.stateElapsed + FixedStepAccumulator.tolerance >= duration
    }

    private mutating func hold(_ pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        pet.velocity = .zero
        advancePresentation(of: &pet, dt: dt, events: &events)
    }

    private func finishActivity(_ pet: inout Pet) {
        if let activity = pet.activity, activity.cooldown > 0 {
            pet.activityCooldowns[activity] = time + activity.cooldown
        }
        pet.activity = nil
        pet.activityDeadline = time
        pet.noProgressElapsed = 0
    }

    /// A forced fallback is bounded and exempt from the ordinary repeat cap.
    private func boundedIdle(_ pet: inout Pet, events: inout [WorldEvent]) {
        finishActivity(&pet)
        pet.activity = .idle
        pet.activityDuration = 2
        pet.activityDeadline = time + 2
        pet.resumeActivity = .idle
        enter(.grounded(.idle), pet: &pet, events: &events)
    }

    private mutating func chooseActivity(_ pet: inout Pet, events: inout [WorldEvent]) {
        finishActivity(&pet)
        let forcedSleep = behavior.restEnabled && pet.needs.energy <= 0.08
        var candidates: [ActivityCandidate] = []
        for activity in Activity.allCases {
            guard (pet.activityCooldowns[activity] ?? 0) <= time + FixedStepAccumulator.tolerance else { continue }
            switch activity {
            case .jump where !behavior.jumpsEnabled || screens.isEmpty: continue
            case .sit where !behavior.restEnabled, .sleep where !behavior.restEnabled: continue
            case .stretch where !behavior.expressionsEnabled, .observe where !behavior.expressionsEnabled: continue
            default: break
            }
            let weight: Double
            if let weights = tuning.activityWeights {
                weight = weights[activity] ?? 0
            } else {
                switch activity {
                case .walk: weight = 4 * (1.5 - pet.personality.laziness)
                case .idle: weight = 2
                case .jump: weight = 0.7 * (0.5 + pet.personality.playfulness)
                case .sit: weight = 1.5 * (0.5 + pet.personality.laziness)
                case .sleep: weight = pet.needs.energy > 0.25 ? 0 : 8 + 10 * pet.personality.laziness
                case .stretch: weight = 0.5 * (0.5 + pet.personality.playfulness)
                case .observe: weight = 1 * (0.5 + pet.personality.curiosity)
                case .explore: weight = 0.8 * (0.5 + pet.personality.curiosity)
                }
            }
            candidates.append(ActivityCandidate(activity, weight: weight))
        }
        let selected =
            forcedSleep
            ? Activity.sleep
            : ActivitySelector.select(
                candidates,
                previous: pet.previousActivity, repetitions: pet.activityRepetitions, random: &random)
        pet.activityDecisionCount += 1
        if !forcedSleep, candidates.contains(where: { $0.weight.isFinite && $0.weight > 0 }) {
            pet.activityRepetitions = selected == pet.previousActivity ? pet.activityRepetitions + 1 : 1
            pet.previousActivity = selected
        }
        pet.activity = selected
        let duration = selected.duration
        pet.activityDuration = duration.lowerBound + (duration.upperBound - duration.lowerBound) * nextUnitRandom()
        pet.activityDeadline = time + pet.activityDuration
        pet.progressPosition = pet.position
        switch selected {
        case .walk, .explore:
            pet.resumeActivity = .walking
            enter(.walking, pet: &pet, events: &events)
        case .idle:
            pet.resumeActivity = .idle
            enter(.grounded(.idle), pet: &pet, events: &events)
        case .jump:
            requestJump(JumpRequest(returnActivity: .idle), pet: &pet, events: &events)
            if pet.state != .grounded(.preparingJump) { boundedIdle(&pet, events: &events) }
        case .sit: enter(.grounded(.sittingDown), pet: &pet, events: &events)
        case .sleep: enter(.grounded(.lyingDown), pet: &pet, events: &events)
        case .stretch: enter(.grounded(.stretching), pet: &pet, events: &events)
        case .observe: enter(.grounded(.observing), pet: &pet, events: &events)
        }
    }

    // MARK: - Explicit jump commands

    private func requestJump(_ request: JumpRequest, pet: inout Pet, events: inout [WorldEvent]) {
        guard pet.state == .walking || pet.state == .grounded(.idle),
            let source = attachedSurface(of: pet), let geometry = pet.contactGeometry,
            let screen = screens.first, pet.jumpRequestID < Int.max
        else { events.append(.jumpRejected(pet.id, .busy)); return }
        if let launch = pet.lastJumpLaunchTime, time + FixedStepAccumulator.tolerance < launch + jumpTuning.cooldown {
            events.append(.jumpRejected(pet.id, .cooldown))
            return
        }
        let target: CGPoint
        let id: SurfaceID
        switch request.target {
        case .vertical:
            id = source.id
            target = pet.position
        case .horizontal(let offset):
            id = source.id
            target = CGPoint(x: pet.position.x + CGFloat(offset), y: source.y)
        case .surface(let surfaceID, let x):
            guard let surface = surfaces.surface(surfaceID), surface.isUsable else {
                events.append(.jumpRejected(pet.id, .invalidTarget))
                return
            }
            id = surfaceID
            target = CGPoint(x: x, y: surface.y)
        }
        guard
            let plan = JumpSolver.solve(
                from: pet.position, target: target, targetSurfaceID: id,
                surfaces: surfaces, geometry: geometry, screen: screen, physics: physics,
                tuning: jumpTuning, visualMargin: pet.edgeMargin)
        else { events.append(.jumpRejected(pet.id, .unreachable)); return }
        pet.jumpRequestID += 1
        pet.jumpPlan = plan
        pet.jumpSource = source
        pet.resumeActivity = request.returnActivity
        enter(.grounded(.preparingJump), pet: &pet, events: &events)
    }

    private func cancelJump(_ pet: inout Pet, events: inout [WorldEvent]) {
        guard pet.jumpPlan != nil || pet.jumpSource != nil else { return }
        pet.jumpPlan = nil
        pet.jumpSource = nil
        events.append(.jumpCancelled(pet.id))
        if pet.state == .grounded(.preparingJump) {
            enter(pet.resumeActivity == .walking ? .walking : .grounded(.idle), pet: &pet, events: &events)
        }
    }

    /// Motion needs 60 Hz. Sleeping animation uses at most its authored FPS; logical time still advances.
    public var preferredFramesPerSecond: Float {
        pets.reduce(Float(0)) { maximum, pet in
            let demand: Float
            switch pet.state {
            case .grounded(.sleeping):
                if pet.animation.definition.clips[pet.animation.requestedClip] != nil {
                    let duration = pet.animation.player.clip.frames.reduce(Double.infinity) { min($0, $1.duration) }
                    demand = Float(min(30, 1 / duration))
                } else {
                    demand = 4
                }
            case .grounded(.idle), .grounded(.sitting), .grounded(.observing), .grounded(.stretching), .spawning,
                .recovering:
                demand = 30
            case .grounded, .airborne: demand = 60
            }
            return max(maximum, demand)
        }
    }

    // MARK: - Placement

    /// Puts an unplaced pet on the spawn surface at a random position and facing, walk clip at frame 0.
    private mutating func place(_ pet: inout Pet, events: inout [WorldEvent]) {
        guard let surface = placementSurface(for: pet) else { return }
        let range = surface.walkableRange(margin: pet.edgeMargin)
        let x = range.lowerBound + CGFloat(nextUnitRandom()) * (range.upperBound - range.lowerBound)
        let facing: Facing = random.next() & 1 == 0 ? .right : .left
        pet.facing = facing
        pet.animation.setFacing(facing)
        pet.animation.request(
            AnimationRequest(clip: BehaviorTuning.walkClip, priority: AnimationRequest.criticalPriority, restart: true))
        setPosition(of: &pet, x: x, on: surface)
        events.append(.placed(pet.id, surface.id))
    }

    /// Exceptional recovery reuses a spawn surface below/above the last finite x, keeping facing and animation
    /// when it fits. Ordinary support loss uses physical falling instead. Returns false when random placement
    /// is needed.
    private func resettle(_ pet: inout Pet, events: inout [WorldEvent]) -> Bool {
        let x = pet.position.x
        guard let surface = placementSurface(for: pet), x.isFinite, surface.minX <= x, x <= surface.maxX else {
            return false
        }
        let range = surface.walkableRange(margin: pet.edgeMargin)
        setPosition(of: &pet, x: min(max(x, range.lowerBound), range.upperBound), on: surface)
        events.append(.placed(pet.id, surface.id))
        return true
    }

    /// Uniform in `0..<1` from the top 53 bits of the injected source.
    private mutating func nextUnitRandom() -> Double {
        Double(random.next() >> 11) * 0x1p-53
    }

    /// Follows a moved surface: same parameter, then clamped into the walkable range (an edge reached this way
    /// fires on the next walking step).
    private func reproject(_ pet: inout Pet) {
        guard let attachment = pet.attachment, let surface = surfaces.surface(attachment.surfaceID),
            surface.isUsable, let geometry = pet.contactGeometry,
            surface.width >= max(geometry.halfWidth, pet.edgeMargin) * 2
        else { return }
        let range = surface.walkableRange(margin: pet.edgeMargin)
        let x = min(max(surface.point(atParameter: attachment.parameter).x, range.lowerBound), range.upperBound)
        setPosition(of: &pet, x: x, on: surface)
    }

    private func setPosition(of pet: inout Pet, x: CGFloat, on surface: Surface) {
        pet.position = CGPoint(x: x, y: surface.y)
        pet.velocity = .zero
        pet.airborneElapsed = 0
        pet.attachment = SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atX: x))
    }

    private func attachedSurface(of pet: Pet) -> Surface? {
        pet.attachment.flatMap { attachment in
            guard let surface = surfaces.surface(attachment.surfaceID), surface.isUsable,
                let geometry = pet.contactGeometry, surface.width >= geometry.halfWidth * 2,
                pet.position.x >= surface.minX + geometry.halfWidth - physics.contactTolerance,
                pet.position.x <= surface.maxX - geometry.halfWidth + physics.contactTolerance,
                abs(pet.position.y - surface.y) <= physics.contactTolerance
            else { return nil }
            return surface
        }
    }

    private func placementSurface(for pet: Pet) -> Surface? {
        guard let geometry = pet.contactGeometry else { return nil }
        func usable(_ surface: Surface) -> Bool {
            guard surface.isUsable, surface.width >= max(geometry.halfWidth, pet.edgeMargin) * 2 else { return false }
            return screens.isEmpty
                || screens.contains {
                    surface.y >= $0.frame.minY && surface.y < $0.frame.maxY
                        && surface.maxX > $0.frame.minX && surface.minX < $0.frame.maxX
                }
        }
        return surfaces.surfaces.first { $0.kind == .dockTop && usable($0) }
            ?? surfaces.surfaces.first { usable($0) }
    }

    // MARK: - Transitions and invariants

    private func enter(_ state: PetState, pet: inout Pet, events: inout [WorldEvent]) {
        let previous = pet.state.kind
        pet.state = state
        pet.stateElapsed = 0
        let clip: String?
        switch state {
        case .grounded(.walking): clip = BehaviorTuning.walkClip
        case .grounded(.landing):
            clip = pet.animation.definition.clips["landing"] != nil ? "landing" : "land"
        case .airborne(.falling): clip = "fall"
        case .airborne(.rising):
            clip = pet.animation.definition.clips["jump"] != nil ? "jump" : "jump-air"
        case .grounded(.idle): clip = "idle"
        case .grounded(.preparingJump): clip = "jump-start"
        case .grounded(.sittingDown): clip = "sit-down"
        case .grounded(.sitting): clip = "sit"
        case .grounded(.standingUp): clip = "stand-up"
        case .grounded(.lyingDown): clip = "lie-down"
        case .grounded(.sleeping): clip = "sleep"
        case .grounded(.wakingUp): clip = "wake-up"
        case .grounded(.stretching): clip = "stretch"
        case .grounded(.observing): clip = "observe"
        case .spawning, .recovering, .grounded(.turning): clip = nil
        }
        if state == .grounded(.idle) || state == .grounded(.preparingJump) { pet.velocity = .zero }
        if let clip {
            pet.animation.transition(
                AnimationRequest(
                    clip: clip,
                    priority: state == .walking || state == .grounded(.idle) ? 10 : AnimationRequest.criticalPriority,
                    restart: state != .walking || previous != .turning))
            pet.animation.rate = state == .walking ? tuning.speedScale : 1
        }
        if previous != state.kind {
            events.append(.stateChanged(pet.id, from: previous, to: state.kind))
        }
    }

    private func recover(_ pet: inout Pet, reason: RecoveryReason, events: inout [WorldEvent]) {
        guard case .recovering = pet.state else {
            cancelJump(&pet, events: &events)
            pet.attachment = nil
            pet.velocity = .zero
            pet.airborneElapsed = 0
            pet.resumeActivity = .walking
            finishActivity(&pet)
            enter(.recovering(reason), pet: &pet, events: &events)
            events.append(.recovered(pet.id, reason: reason))
            return
        }
    }

    /// Validate airborne as well as attached bodies; lifecycle states wait without busy recovery loops.
    @discardableResult
    private func validate(_ pet: inout Pet, events: inout [WorldEvent]) -> Bool {
        switch pet.state {
        case .spawning, .recovering: return true
        case .grounded, .airborne: break
        }
        let invalidContact: Bool
        switch pet.state {
        case .airborne: invalidContact = pet.attachment != nil
        case .grounded: invalidContact = pet.attachment == nil
        case .spawning, .recovering: invalidContact = false
        }
        if invalidContact {
            recover(&pet, reason: .invalidContact, events: &events)
            return false
        }
        if !pet.position.x.isFinite || !pet.position.y.isFinite
            || !pet.velocity.dx.isFinite || !pet.velocity.dy.isFinite
        {
            recover(&pet, reason: .invalidNumbers, events: &events)
            return false
        }
        if !screens.isEmpty {
            let margin = tuning.outOfBoundsMargin
            if !screens.contains(where: { $0.frame.insetBy(dx: -margin, dy: -margin).contains(pet.position) }) {
                recover(&pet, reason: .outOfBounds, events: &events)
                return false
            }
        }
        return true
    }

    public var needsSimulationSteps: Bool {
        pets.contains { pet in
            if behavior.isEnabled, attachedSurface(of: pet) != nil { return true }
            switch pet.state {
            case .spawning: return pet.attachment != nil || placementSurface(for: pet) != nil
            case .recovering: return placementSurface(for: pet) != nil
            case .grounded(.idle):
                guard surfaces.surfaces.contains(where: { $0.isUsable }) else { return false }
                return attachedSurface(of: pet) == nil
                    || !pet.position.x.isFinite || !pet.position.y.isFinite
                    || !pet.velocity.dx.isFinite || !pet.velocity.dy.isFinite
                    || (!screens.isEmpty
                        && !screens.contains {
                            $0.frame.insetBy(dx: -tuning.outOfBoundsMargin, dy: -tuning.outOfBoundsMargin)
                                .contains(pet.position)
                        })
                    || pet.lastJumpLaunchTime.map { time < $0 + jumpTuning.cooldown } == true
            case .grounded, .airborne: return surfaces.surfaces.contains { $0.isUsable }
            }
        }
    }

    public var needsAnimationFrames: Bool {
        surfaces.surfaces.contains { $0.isUsable } && pets.contains { isAnimating($0) }
    }

    private func isAnimating(_ pet: Pet) -> Bool {
        switch pet.state {
        case .grounded(.walking): return true
        case .grounded(.landing), .grounded(.idle), .grounded(.preparingJump), .airborne:
            return pet.animation.definition.clips[pet.animation.requestedClip] != nil
                && pet.animation.rate > 0 && !pet.animation.player.isFinished
        case .grounded(.sittingDown), .grounded(.sitting), .grounded(.standingUp), .grounded(.lyingDown),
            .grounded(.sleeping), .grounded(.wakingUp), .grounded(.stretching), .grounded(.observing):
            return pet.animation.definition.clips[pet.animation.requestedClip] != nil
                && pet.animation.rate > 0 && !pet.animation.player.isFinished
        case .grounded(.turning), .spawning, .recovering: return false
        }
    }

    // MARK: - Snapshot

    /// Fills `snapshot` with the current pets, reusing its storage (no allocation per frame once warm).
    public func writeSnapshot(into snapshot: inout RenderSnapshot) {
        snapshot.pets.removeAll(keepingCapacity: true)
        for pet in pets {
            snapshot.pets.append(
                PetRenderState(
                    id: pet.id, characterID: pet.characterID, position: pet.position, size: pet.size,
                    frame: pet.animation.currentFrame,
                    isVisible: pet.attachment != nil || { if case .airborne = pet.state { true } else { false } }(),
                    isAnimating: isAnimating(pet)))
        }
    }

    public func snapshot() -> RenderSnapshot {
        var snapshot = RenderSnapshot()
        writeSnapshot(into: &snapshot)
        return snapshot
    }
}
