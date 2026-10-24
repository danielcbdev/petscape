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
    private var interactionTuning: InteractionTuning
    private var cursorLocation: CGPoint?
    private var cursorReactionsEnabled = true
    private var reduceMotion = false
    public var tuning: BehaviorTuning
    var physics = PhysicsTuning()
    var jumpTuning = JumpTuning()
    private var pendingEvents: [WorldEvent] = []

    private var random: any RandomSource
    private var nextPetID = 1
    /// Reused per step so stepping does not allocate.
    private var animationEvents: [AnimationEvent] = []

    public init(
        tuning: BehaviorTuning = BehaviorTuning(), interactionTuning: InteractionTuning = .default,
        random: any RandomSource
    ) {
        self.tuning = tuning
        self.interactionTuning = interactionTuning
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
        case .setCursorLocation(let location):
            cursorLocation = location.flatMap { $0.x.isFinite && $0.y.isFinite ? $0 : nil }
        case .setCursorReactionsEnabled(let enabled):
            cursorReactionsEnabled = enabled
            if !enabled {
                var events: [WorldEvent] = []
                for index in pets.indices where pets[index].state == .grounded(.reactingToCursor) {
                    var pet = pets[index]
                    pet.cursorInterest.cancel()
                    finishCursorReaction(&pet, allowResume: false, events: &events)
                    pets[index] = pet
                }
                pendingEvents.append(contentsOf: events)
            }
        case .setReduceMotion(let enabled):
            reduceMotion = enabled
            if enabled {
                for index in pets.indices
                where pets[index].state == .grounded(.reactingToCursor)
                    || pets[index].state == .grounded(.reactingToClick)
                {
                    pets[index].animation.transition(
                        AnimationRequest(clip: "idle", priority: AnimationRequest.criticalPriority))
                }
            }
        case .configureBehavior(let settings):
            behavior = settings
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if (!settings.isEnabled || !settings.jumpsEnabled),
                    (pet.activity == .jump || pet.activity == .windowExcursion),
                    pet.state == .grounded(.preparingJump)
                {
                    cancelJump(&pet, events: &events)
                    pet.windowClimbPlan = nil
                    pet.windowExcursionPhase = nil
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
                if !settings.expressionsEnabled,
                    pet.state == .grounded(.reactingToCursor)
                        || pet.state == .grounded(.reactingToClick)
                {
                    pet.cursorInterest.cancel()
                    if pet.state == .grounded(.reactingToCursor) {
                        finishCursorReaction(&pet, allowResume: false, events: &events)
                    } else {
                        finishClickReaction(&pet, events: &events)
                    }
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
                if let interactionID = pet.interactionID {
                    endInteraction(&pet, events: &events, fallingIfHeld: true)
                    events.append(.interactionEnded(pet.id, interactionID))
                }
                pet.scale = scale
                let size = pet.animation.definition.displaySize
                pet.contactGeometry = ContactGeometry(
                    displaySize: CGSize(width: size.width, height: size.height), scale: scale)
                cancelJump(&pet, events: &events)
                // Keep the canonical contact fixed whenever it still fits; clamp to the new surface bounds.
                reproject(&pet)
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
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if let interactionID = pet.interactionID {
                    endInteraction(&pet, events: &events, fallingIfHeld: true)
                    events.append(.interactionEnded(pet.id, interactionID))
                }
                pets[index] = pet
            }
            self.screens = screens
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
            let occludedWindowSegments = Set(
                pets.compactMap { pet -> SurfaceID? in
                    guard let attachment = pet.attachment,
                        let previous = surfaces.surface(attachment.surfaceID),
                        SurfaceMap.windowIdentity(for: previous.id) != nil,
                        changes.contains(where: { change in
                            guard case .moved(let next) = change, next.id == attachment.surfaceID,
                                next.id.rawValue.contains(":cover:")
                            else { return false }
                            if previous.isVertical {
                                let height = pet.contactGeometry?.height ?? 0
                                return pet.position.y < next.minY + height || pet.position.y > next.maxY
                            }
                            let halfWidth = pet.contactGeometry?.halfWidth ?? 0
                            return pet.position.x < next.minX + halfWidth || pet.position.x > next.maxX - halfWidth
                        })
                    else { return nil }
                    return attachment.surfaceID
                })
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if let interactionID = pet.interactionID {
                    endInteraction(&pet, events: &events, fallingIfHeld: true)
                    events.append(.interactionEnded(pet.id, interactionID))
                }
                pets[index] = pet
            }
            surfaces.apply(changes)
            for index in pets.indices {
                var pet = pets[index]
                if pet.attachment == nil {
                    if pet.state == .spawning { place(&pet, events: &events) }
                } else if let attachment = pet.attachment, occludedWindowSegments.contains(attachment.surfaceID) {
                    pet.attachment = nil
                    pet.velocity = .zero
                    pet.airborneElapsed = 0
                    cancelJump(&pet, events: &events)
                    finishActivity(&pet)
                    enter(.airborne(.falling), pet: &pet, events: &events)
                    events.append(.surfaceLost(pet.id, attachment.surfaceID))
                } else if let attachment = pet.attachment,
                    changes.contains(where: { change in
                        switch change {
                        case .added(let surface), .moved(let surface): surface.id == attachment.surfaceID
                        case .removed: false
                        }
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
                if let plan = pet.windowClimbPlan, surfaces.surface(plan.target.id) != plan.target {
                    pet.windowClimbPlan = nil
                    pet.windowExcursionPhase = nil
                    if pet.state == .grounded(.preparingJump) {
                        finishActivity(&pet)
                        enter(.grounded(.idle), pet: &pet, events: &events)
                    }
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
        case .interaction(let id, let command):
            applyInteraction(id, command: command)
        }
    }

    private mutating func applyInteraction(_ petID: PetID, command: InteractionCommand) {
        if case .observeCursor(let location) = command {
            cursorLocation = location.x.isFinite && location.y.isFinite ? location : nil
            return
        }
        guard let index = pets.firstIndex(where: { $0.id == petID }) else { return }
        var pet = pets[index]
        var events: [WorldEvent] = []
        switch command {
        case .press(let id):
            guard id.isValid, pet.interactionID == nil,
                pet.attachment != nil || isAirborne(pet.state)
            else {
                if id.isValid { events.append(.interactionRejected(petID, id)) }
                break
            }
            pet.interactionID = id
            pet.interactionIsHeld = false
            pet.interactionSavedState = pet.state
            pet.interactionSavedStateElapsed = pet.stateElapsed
            pet.interactionSavedActivity = pet.activity
            pet.interactionSavedActivityRemaining = max(0, pet.activityDeadline - time)
            events.append(.interactionAccepted(petID, id))
        case .beginHold(let id, let target):
            guard pet.interactionID == id, !pet.interactionIsHeld else {
                if id.isValid { events.append(.interactionRejected(petID, id)) }
                break
            }
            guard isFinite(target), let clamped = heldTarget(target, for: pet) else {
                endInteraction(&pet, events: &events, fallingIfHeld: false)
                events.append(.interactionRejected(petID, id))
                events.append(.interactionEnded(petID, id))
                break
            }
            cancelJump(&pet, events: &events)
            finishActivity(&pet)
            pet.cursorInterest.cancel()
            pet.cursorSavedActivity = nil
            pet.cursorSavedActivityRemaining = 0
            pet.attachment = nil
            pet.velocity = .zero
            pet.airborneElapsed = 0
            pet.activity = nil
            pet.interactionIsHeld = true
            pet.heldPickupPresentationActive = true
            pet.interactionTarget = clamped
            pet.position = clamped
            enter(.held, pet: &pet, events: &events)
        case .moveHold(let id, let target):
            guard pet.interactionID == id, pet.interactionIsHeld, isFinite(target) else {
                if id.isValid { events.append(.interactionRejected(petID, id)) }
                break
            }
            pet.interactionTarget = target
        case .release(let id, let target):
            guard pet.interactionID == id, pet.interactionIsHeld else {
                if id.isValid { events.append(.interactionRejected(petID, id)) }
                break
            }
            if isFinite(target), let clamped = heldTarget(target, for: pet) { pet.position = clamped }
            clearInteraction(&pet)
            pet.heldPickupPresentationActive = false
            pet.velocity = .zero
            pet.attachment = nil
            pet.airborneElapsed = 0
            enter(.airborne(.falling), pet: &pet, events: &events)
            events.append(.interactionEnded(petID, id))
        case .cancel(let id, _):
            guard pet.interactionID == id else {
                if id.isValid { events.append(.interactionRejected(petID, id)) }
                break
            }
            endInteraction(&pet, events: &events, fallingIfHeld: true)
            events.append(.interactionEnded(petID, id))
        case .click:
            if let id = pet.interactionID, !pet.interactionIsHeld {
                endInteraction(&pet, events: &events, fallingIfHeld: false)
                events.append(.interactionEnded(petID, id))
            }
            if pet.state == .grounded(.sleeping) || pet.state == .grounded(.lyingDown) {
                finishActivity(&pet)
                enter(.grounded(.wakingUp), pet: &pet, events: &events)
            } else if behavior.expressionsEnabled,
                time >= pet.clickCooldownUntil,
                pet.state == .walking || pet.state == .grounded(.idle)
                    || pet.state == .grounded(.observing)
            {
                pet.clickSavedState = pet.state
                pet.clickSavedStateElapsed = pet.stateElapsed
                pet.clickSavedActivity = pet.activity
                pet.clickSavedActivityRemaining = max(0, pet.activityDeadline - time)
                enter(.grounded(.reactingToClick), pet: &pet, events: &events)
            }
        case .observeCursor:
            break
        }
        pets[index] = pet
        pendingEvents.append(contentsOf: events)
    }

    private mutating func endInteraction(
        _ pet: inout Pet, events: inout [WorldEvent], fallingIfHeld: Bool
    ) {
        let wasHeld = pet.interactionIsHeld
        let savedState = pet.interactionSavedState
        let savedElapsed = pet.interactionSavedStateElapsed
        let savedActivity = pet.interactionSavedActivity
        let remaining = pet.interactionSavedActivityRemaining
        if wasHeld, fallingIfHeld, let target = pet.interactionTarget,
            let clamped = heldTarget(target, for: pet)
        {
            pet.position = clamped
        }
        clearInteraction(&pet)
        if wasHeld, fallingIfHeld {
            pet.velocity = .zero
            pet.attachment = nil
            pet.airborneElapsed = 0
            enter(.airborne(.falling), pet: &pet, events: &events)
        } else if !wasHeld, let savedState {
            pet.state = savedState
            pet.stateElapsed = savedElapsed
            if let savedActivity {
                pet.activity = savedActivity
                pet.activityDuration = remaining
                pet.activityDeadline = time + remaining
            }
        }
    }

    private func clearInteraction(_ pet: inout Pet) {
        pet.interactionID = nil
        pet.interactionIsHeld = false
        pet.heldPickupPresentationActive = false
        pet.interactionTarget = nil
        pet.interactionSavedState = nil
        pet.interactionSavedStateElapsed = 0
        pet.interactionSavedActivity = nil
        pet.interactionSavedActivityRemaining = 0
    }

    private mutating func finishClickReaction(_ pet: inout Pet, events: inout [WorldEvent]) {
        pet.clickCooldownUntil = time + interactionTuning.clickRepeatCooldown
        guard let savedState = pet.clickSavedState else {
            boundedIdle(&pet, events: &events)
            return
        }
        let savedElapsed = pet.clickSavedStateElapsed
        let savedActivity = pet.clickSavedActivity
        let remaining = pet.clickSavedActivityRemaining
        pet.clickSavedState = nil
        pet.clickSavedActivity = nil
        pet.clickSavedStateElapsed = 0
        pet.clickSavedActivityRemaining = 0
        enter(savedState, pet: &pet, events: &events)
        pet.stateElapsed = savedElapsed
        if let savedActivity {
            pet.activity = savedActivity
            pet.activityDuration = remaining
            pet.activityDeadline = time + remaining
        }
    }

    private func isAirborne(_ state: PetState) -> Bool {
        if case .airborne = state { return true }
        return false
    }

    private func isFinite(_ point: CGPoint) -> Bool { point.x.isFinite && point.y.isFinite }

    private func heldTarget(_ target: CGPoint, for pet: Pet) -> CGPoint? {
        guard let screen = screens.first else { return target }
        let anchor = pet.animation.currentFrame.anchor
        let size = pet.size
        let minX = screen.frame.minX + CGFloat(anchor.x) * size.width
        let maxX = screen.frame.maxX - (1 - CGFloat(anchor.x)) * size.width
        let minY = screen.frame.minY + CGFloat(anchor.y) * size.height
        let maxY = screen.frame.maxY - (1 - CGFloat(anchor.y)) * size.height
        guard minX <= maxX, minY <= maxY else { return nil }
        return CGPoint(x: min(max(target.x, minX), maxX), y: min(max(target.y, minY), maxY))
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
        if pet.interactionID != nil, !pet.interactionIsHeld { return }
        pet.stateElapsed += dt
        if behavior.isEnabled, !pet.interactionIsHeld {
            pet.needs.advance(by: dt, sleeping: pet.state == .grounded(.sleeping))
        }
        if let attachment = pet.attachment, attachedSurface(of: pet) == nil {
            let lostClimbSide: WallSide?
            if case .grounded(.climbing(let side)) = pet.state { lostClimbSide = side } else { lostClimbSide = nil }
            pet.attachment = nil
            pet.airborneElapsed = 0
            finishActivity(&pet)
            if let lostClimbSide {
                pet.velocity = CGVector(dx: climbFallVelocityX(side: lostClimbSide, pet: pet), dy: 0)
                enterPreservingSpriteRect(
                    .airborne(.falling), facing: lostClimbSide == .left ? .right : .left,
                    pet: &pet, events: &events)
            } else {
                enter(.airborne(.falling), pet: &pet, events: &events)
            }
            events.append(.surfaceLost(pet.id, attachment.surfaceID))
        }
        // Rest phases and cursor reactions share one budget, so chained activities cannot
        // leave a supported autonomous pet stationary indefinitely. Held/paused pets are exempt.
        if behavior.isEnabled, pet.interactionID == nil, attachedSurface(of: pet) != nil,
            isStationaryActivity(pet.state)
        {
            pet.stationaryElapsed += dt
            if pet.stationaryElapsed + FixedStepAccumulator.tolerance >= 5 {
                pet.cursorInterest.cancel()
                pet.cursorSavedActivity = nil
                pet.cursorSavedActivityRemaining = 0
                pet.clickSavedState = nil
                pet.clickSavedActivity = nil
                pet.clickSavedStateElapsed = 0
                pet.clickSavedActivityRemaining = 0
                pet.clickCooldownUntil = time + interactionTuning.clickRepeatCooldown
                beginAutonomousWalk(&pet, events: &events)
            }
        } else {
            pet.stationaryElapsed = 0
        }
        pet.cursorEvaluationElapsed += dt
        let cursorInterval = pet.state == .grounded(.sleeping) ? 0.5 : 0.1
        if pet.cursorEvaluationElapsed + FixedStepAccumulator.tolerance >= cursorInterval {
            let evaluationDt = pet.cursorEvaluationElapsed
            pet.cursorEvaluationElapsed = 0
            updateCursorInterest(&pet, dt: evaluationDt, events: &events)
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
                    if let wall = wall(at: pet.position, facing: pet.facing) {
                        let side: WallSide = wall.kind == .screenLeft ? .left : .right
                        let facing: Facing = side == .left ? .left : .right
                        let climbClip = pet.animation.definition.clip(named: "climb", facing: facing).clip
                        let anchorY = CGFloat(climbClip.anchor.y)
                        let climbY =
                            pet.position.y + (anchorY - CGFloat(pet.animation.currentFrame.anchor.y))
                            * pet.size.height
                        guard let range = verticalRange(for: pet, on: wall, anchorY: anchorY),
                            range.contains(climbY)
                        else {
                            enter(.turning(to: pet.facing.opposite), pet: &pet, events: &events)
                            return
                        }
                        pet.position = CGPoint(x: wall.segment.start.x, y: climbY)
                        pet.attachment = SurfaceAttachment(surfaceID: wall.id, parameter: wall.parameter(atY: climbY))
                        pet.facing = facing
                        pet.animation.setFacing(facing)
                        enter(.grounded(.climbing(wall: side)), pet: &pet, events: &events)
                    } else {
                        enter(.turning(to: pet.facing.opposite), pet: &pet, events: &events)
                    }
                }
            case .turning(let newFacing):
                pet.velocity = .zero
                if behavior.isEnabled { pet.noProgressElapsed += dt }
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= tuning.turnHold {
                    pet.facing = newFacing
                    pet.animation.setFacing(newFacing)
                    enter(.walking, pet: &pet, events: &events)
                }
            case .climbing(let side):
                guard let attachment = pet.attachment, let support = surfaces.surface(attachment.surfaceID) else {
                    pet.attachment = nil
                    pet.airborneElapsed = 0
                    pet.velocity = CGVector(dx: side == .left ? 150 : -150, dy: 0)
                    enterPreservingSpriteRect(
                        .airborne(.falling), facing: side == .left ? .right : .left,
                        pet: &pet, events: &events)
                    fall(&pet, dt: dt, events: &events)
                    return
                }
                guard support.isVertical, isClimbable(support.kind, on: side),
                    let range = verticalRange(for: pet, on: support),
                    let result = PhysicsStepper.climbing(
                        position: pet.position, on: support, verticalRange: range, speed: 120, dt: dt)
                else { return recover(&pet, reason: .invalidContact, events: &events) }
                commit(result, to: &pet)
                advancePresentation(of: &pet, dt: dt, events: &events)
                if result.edgeReached {
                    if support.kind == .windowLeft || support.kind == .windowRight,
                        let identity = SurfaceMap.windowIdentity(for: support.id),
                        let geometry = pet.contactGeometry,
                        let top = windowTop(for: support, identity: identity, geometry: geometry)
                    {
                        let direction: Facing = support.kind == .windowLeft ? .right : .left
                        let x =
                            support.kind == .windowLeft
                            ? top.minX + geometry.halfWidth
                            : top.maxX - geometry.halfWidth
                        enterPreservingSpriteRect(.walking, facing: direction, pet: &pet, events: &events)
                        setPosition(of: &pet, x: x, on: top)
                        events.append(.landed(pet.id, top.id))
                        let duration = 5 + nextUnitRandom() * 12
                        pet.activity = .windowExcursion
                        pet.activityDuration = duration
                        pet.activityDeadline = time + duration
                        pet.windowExcursionPhase = .walkingOnTop(identity, side)
                    } else {
                        pet.attachment = nil
                        pet.airborneElapsed = 0
                        pet.velocity = CGVector(dx: climbFallVelocityX(side: side, pet: pet), dy: 0)
                        enterPreservingSpriteRect(
                            .airborne(.falling), facing: side == .left ? .right : .left,
                            pet: &pet, events: &events)
                    }
                }
            case .landing:
                pet.velocity = .zero
                advancePresentation(of: &pet, dt: dt, events: &events)
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= jumpTuning.landingDuration {
                    if behavior.isEnabled, pet.resumeActivity == .walking,
                        pet.activity == nil || pet.activity == .jump
                    {
                        beginAutonomousWalk(&pet, events: &events)
                    } else {
                        enter(pet.resumeActivity == .walking ? .walking : .grounded(.idle), pet: &pet, events: &events)
                        if pet.activity == .jump { finishActivity(&pet) }
                    }
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
            case .reactingToCursor:
                hold(&pet, dt: dt, events: &events)
            case .reactingToClick:
                hold(&pet, dt: dt, events: &events)
                if elapsed(pet, atLeast: interactionTuning.clickReactionDuration) {
                    finishClickReaction(&pet, events: &events)
                }
            case .preparingJump:
                pet.velocity = .zero
                if pet.stateElapsed + FixedStepAccumulator.tolerance >= jumpTuning.preparationDuration {
                    let launchVelocity: CGVector
                    if let plan = pet.windowClimbPlan {
                        guard pet.jumpSource == surface, surfaces.surface(plan.target.id) == plan.target,
                            pet.windowExcursionPhase == .jumpingToSide(plan.target.id)
                        else {
                            cancelJump(&pet, events: &events)
                            pet.windowClimbPlan = nil
                            pet.windowExcursionPhase = nil
                            boundedIdle(&pet, events: &events)
                            return
                        }
                        launchVelocity = plan.initialVelocity
                    } else {
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
                        launchVelocity = plan.initialVelocity
                    }
                    pet.lastJumpLaunchTime = time
                    pet.attachment = nil
                    pet.velocity = launchVelocity
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
        case .held:
            if pet.heldPickupPresentationActive,
                elapsed(pet, atLeast: interactionTuning.pickupPresentationDuration)
            {
                pet.heldPickupPresentationActive = false
                pet.animation.transition(
                    AnimationRequest(clip: "held", priority: AnimationRequest.criticalPriority))
            }
            if let target = pet.interactionTarget, let clamped = heldTarget(target, for: pet) {
                pet.position = clamped
            }
            pet.velocity = .zero
            advancePresentation(of: &pet, dt: dt, events: &events)
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
                tuning: physics, surfaces: surfaces, geometry: geometry, visualRange: visualRange(for: pet),
                wallTarget: pet.windowClimbPlan?.target)
        else { return recover(&pet, reason: .invalidNumbers, events: &events) }
        let wasRising = pet.state == .airborne(.rising)
        commit(result, to: &pet)
        if wasRising && result.velocity.dy <= 0 {
            events.append(.apex(pet.id))
            enter(.airborne(.falling), pet: &pet, events: &events)
        }
        if let surfaceID = result.landedSurfaceID {
            events.append(.landed(pet.id, surfaceID))
            let landedSurface = surfaces.surface(surfaceID)
            if let surface = landedSurface, surface.isVertical,
                (surface.kind == .windowLeft || surface.kind == .windowRight)
            {
                let side: WallSide = surface.kind == .windowLeft ? .left : .right
                pet.windowClimbPlan = nil
                pet.jumpPlan = nil
                pet.jumpSource = nil
                pet.windowExcursionPhase = .climbing(surfaceID)
                enter(.grounded(.climbing(wall: side)), pet: &pet, events: &events)
                pet.position.x = surface.segment.start.x
                pet.attachment = SurfaceAttachment(
                    surfaceID: surface.id, parameter: surface.parameter(atY: pet.position.y))
            } else {
                pet.windowClimbPlan = nil
                pet.jumpPlan = nil
                pet.jumpSource = nil
                if case .jumpingToSide = pet.windowExcursionPhase {
                    pet.windowExcursionPhase = nil
                    finishActivity(&pet)
                }
                if case .returningToDock = pet.windowExcursionPhase,
                    landedSurface?.kind == .dockTop
                {
                    pet.windowExcursionPhase = nil
                    finishActivity(&pet)
                }
                enter(.grounded(.landing), pet: &pet, events: &events)
            }
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

    private mutating func updateCursorInterest(_ pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        let eligibleState: Bool
        switch pet.state {
        case .walking, .grounded(.idle), .grounded(.observing): eligibleState = true
        default: eligibleState = false
        }
        let anchor = pet.animation.currentFrame.anchor
        let size = pet.size
        let spriteRect = CGRect(
            x: pet.position.x - CGFloat(anchor.x) * size.width,
            y: pet.position.y - CGFloat(anchor.y) * size.height,
            width: size.width, height: size.height)
        let context = CursorInterestContext(
            spriteRect: spriteRect, scale: pet.scale, curiosity: pet.personality.curiosity,
            energy: pet.needs.energy,
            isEligible: cursorReactionsEnabled && cursorLocation != nil && eligibleState
                && pet.stateElapsed >= 0.5 && attachedSurface(of: pet) != nil,
            expressionsEnabled: behavior.expressionsEnabled)
        let event = pet.cursorInterest.advance(location: cursorLocation ?? .zero, dt: dt, context: context)
        switch event {
        case .began(let location, let duration):
            pet.cursorSavedActivity = pet.activity
            pet.cursorSavedActivityRemaining = max(0, pet.activityDeadline - time)
            pet.activity = nil
            pet.activityDuration = duration
            pet.activityDeadline = time + duration
            let horizontal = location.x - pet.position.x
            if horizontal >= 8 { pet.facing = .right; pet.animation.setFacing(.right) }
            if horizontal <= -8 { pet.facing = .left; pet.animation.setFacing(.left) }
            enter(.grounded(.reactingToCursor), pet: &pet, events: &events)
        case .ended:
            finishCursorReaction(&pet, allowResume: true, events: &events)
        case nil:
            break
        }
    }

    private mutating func finishCursorReaction(
        _ pet: inout Pet, allowResume: Bool, events: inout [WorldEvent]
    ) {
        let savedActivity = pet.cursorSavedActivity
        let remaining = pet.cursorSavedActivityRemaining
        pet.cursorSavedActivity = nil
        pet.cursorSavedActivityRemaining = 0
        guard allowResume, let savedActivity, attachedSurface(of: pet) != nil else {
            boundedIdle(&pet, events: &events)
            return
        }
        pet.activity = savedActivity
        pet.activityDuration = remaining
        pet.activityDeadline = time + remaining
        switch savedActivity {
        case .walk, .explore:
            pet.resumeActivity = .walking
            enter(.walking, pet: &pet, events: &events)
        case .idle:
            pet.resumeActivity = .idle
            enter(.grounded(.idle), pet: &pet, events: &events)
        case .observe where behavior.expressionsEnabled:
            enter(.grounded(.observing), pet: &pet, events: &events)
        default:
            boundedIdle(&pet, events: &events)
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

    private func isStationaryActivity(_ state: PetState) -> Bool {
        switch state {
        case .grounded(.walking), .grounded(.climbing), .grounded(.preparingJump), .grounded(.landing): false
        case .grounded: true
        default: false
        }
    }

    /// Guarantees an actual walking interval after a stop or an autonomous landing.
    private func beginAutonomousWalk(_ pet: inout Pet, events: inout [WorldEvent]) {
        finishActivity(&pet)
        pet.activity = .walk
        pet.activityDecisionCount += 1
        pet.activityDuration = Activity.walk.duration.lowerBound
        pet.activityDeadline = time + pet.activityDuration
        pet.progressPosition = pet.position
        pet.stationaryElapsed = 0
        pet.resumeActivity = .walking
        enter(.walking, pet: &pet, events: &events)
    }

    private mutating func chooseActivity(_ pet: inout Pet, events: inout [WorldEvent]) {
        if case .approachingWindowSide(let surfaceID) = pet.windowExcursionPhase {
            attemptWindowClimb(to: surfaceID, for: &pet, events: &events)
            return
        }
        if case .walkingOnTop(let identity, let side) = pet.windowExcursionPhase,
            time + FixedStepAccumulator.tolerance >= pet.activityDeadline
        {
            finishActivity(&pet)
            pet.windowExcursionPhase = .returningToDock(identity, side)
        }
        if case .returningToDock(_, let side) = pet.windowExcursionPhase {
            attemptWindowReturn(&pet, toward: side, events: &events)
            return
        }
        finishActivity(&pet)
        let forcedSleep =
            behavior.restEnabled && pet.needs.energy <= 0.08
            && (pet.activityCooldowns[.sleep] ?? 0) <= time + FixedStepAccumulator.tolerance
        var candidates: [ActivityCandidate] = []
        for activity in Activity.allCases {
            guard (pet.activityCooldowns[activity] ?? 0) <= time + FixedStepAccumulator.tolerance else { continue }
            switch activity {
            case .jump where !behavior.jumpsEnabled || screens.isEmpty: continue
            case .windowExcursion where !behavior.jumpsEnabled || eligibleWindowSideSurfaces(for: pet).isEmpty: continue
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
                case .idle: weight = 0.1
                case .jump: weight = 0.7 * (0.5 + pet.personality.playfulness)
                case .sit: weight = 0.1 * (0.5 + pet.personality.laziness)
                case .sleep: weight = pet.needs.energy > 0.25 ? 0 : 0.2 * (0.5 + pet.personality.laziness)
                case .stretch: weight = 0.15 * (0.5 + pet.personality.playfulness)
                case .observe: weight = 0.15 * (0.5 + pet.personality.curiosity)
                case .explore: weight = 0.8 * (0.5 + pet.personality.curiosity)
                case .windowExcursion: weight = 0.6 * (0.5 + pet.personality.curiosity)
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
            requestJump(JumpRequest(returnActivity: .walking), pet: &pet, events: &events)
            if pet.state != .grounded(.preparingJump) { boundedIdle(&pet, events: &events) }
        case .windowExcursion:
            if !startWindowExcursion(&pet, events: &events) {
                pet.activityCooldowns[.windowExcursion] = time + 20
                boundedIdle(&pet, events: &events)
            }
        case .sit: enter(.grounded(.sittingDown), pet: &pet, events: &events)
        case .sleep: enter(.grounded(.lyingDown), pet: &pet, events: &events)
        case .stretch: enter(.grounded(.stretching), pet: &pet, events: &events)
        case .observe: enter(.grounded(.observing), pet: &pet, events: &events)
        }
    }

    private func eligibleWindowSideSurfaces(for pet: Pet) -> [Surface] {
        guard attachedSurface(of: pet)?.kind == .dockTop else { return [] }
        return surfaces.surfaces.filter { side in
            guard side.isVertical, (side.kind == .windowLeft || side.kind == .windowRight),
                let identity = SurfaceMap.windowIdentity(for: side.id),
                side.id.rawValue.hasSuffix(":\(identity):top"),
                let geometry = pet.contactGeometry,
                windowTop(for: side, identity: identity, geometry: geometry) != nil
            else { return false }
            return true
        }
    }

    private mutating func startWindowExcursion(_ pet: inout Pet, events: inout [WorldEvent]) -> Bool {
        guard let source = attachedSurface(of: pet), source.kind == .dockTop,
            pet.contactGeometry != nil, screens.first != nil
        else { return false }
        let targets = eligibleWindowSideSurfaces(for: pet).sorted { $0.id.rawValue < $1.id.rawValue }
        let identities = Array(Set(targets.compactMap { SurfaceMap.windowIdentity(for: $0.id) })).sorted()
        guard !identities.isEmpty else { return false }
        let startIndex = Int(random.next() % UInt64(identities.count))
        for offset in 0..<identities.count {
            let identity = identities[(startIndex + offset) % identities.count]
            let sides = targets.filter { SurfaceMap.windowIdentity(for: $0.id) == identity }
                .sorted { abs($0.minX - pet.position.x) < abs($1.minX - pet.position.x) }
            for side in sides {
                if launchWindowClimb(to: side, source: source, pet: &pet, events: &events) { return true }
                guard let launchX = windowLaunchX(for: side, on: source, pet: pet),
                    let targetY = windowClimbTargetY(for: side, startY: source.y, pet: pet),
                    let geometry = pet.contactGeometry, let screen = screens.first,
                    WindowClimbSolver.solve(
                        from: CGPoint(x: launchX, y: source.y), target: side, targetY: targetY,
                        surfaces: surfaces, geometry: geometry, screen: screen, physics: physics,
                        tuning: jumpTuning, visualMargin: pet.edgeMargin) != nil
                else { continue }
                pet.windowExcursionPhase = .approachingWindowSide(side.id)
                pet.activity = .windowExcursion
                pet.activityDeadline = time
                attemptWindowClimb(to: side.id, for: &pet, events: &events)
                return true
            }
        }
        return false
    }

    private mutating func attemptWindowClimb(
        to surfaceID: SurfaceID, for pet: inout Pet, events: inout [WorldEvent]
    ) {
        guard let side = surfaces.surface(surfaceID),
            eligibleWindowSideSurfaces(for: pet).contains(where: { $0.id == surfaceID }),
            let source = attachedSurface(of: pet), source.kind == .dockTop
        else {
            pet.windowExcursionPhase = nil
            boundedIdle(&pet, events: &events)
            return
        }
        if launchWindowClimb(to: side, source: source, pet: &pet, events: &events) { return }
        guard let launchX = windowLaunchX(for: side, on: source, pet: pet) else {
            pet.windowExcursionPhase = nil
            boundedIdle(&pet, events: &events)
            return
        }
        let delta = launchX - pet.position.x
        guard abs(delta) > physics.contactTolerance else {
            pet.windowExcursionPhase = nil
            boundedIdle(&pet, events: &events)
            return
        }
        let facing: Facing = delta > 0 ? .right : .left
        pet.facing = facing
        pet.animation.setFacing(facing)
        pet.activity = .windowExcursion
        let speed = max(1, tuning.fallbackWalkSpeed * tuning.speedScale * pet.scale)
        pet.activityDuration = Double(abs(delta) / CGFloat(speed))
        pet.activityDeadline = time + pet.activityDuration
        enter(.walking, pet: &pet, events: &events)
    }

    private mutating func launchWindowClimb(
        to side: Surface, source: Surface, pet: inout Pet, events: inout [WorldEvent]
    ) -> Bool {
        guard let geometry = pet.contactGeometry, let screen = screens.first,
            let targetY = windowClimbTargetY(for: side, startY: pet.position.y, pet: pet),
            let plan = WindowClimbSolver.solve(
                from: pet.position, target: side, targetY: targetY, surfaces: surfaces,
                geometry: geometry, screen: screen, physics: physics, tuning: jumpTuning,
                visualMargin: pet.edgeMargin)
        else { return false }
        pet.windowClimbPlan = plan
        pet.jumpPlan = nil
        pet.jumpSource = source
        let facing: Facing = side.kind == .windowLeft ? .right : .left
        pet.facing = facing
        pet.animation.setFacing(facing)
        pet.windowExcursionPhase = .jumpingToSide(side.id)
        pet.resumeActivity = .walking
        enter(.grounded(.preparingJump), pet: &pet, events: &events)
        return true
    }

    private func windowLaunchX(for side: Surface, on source: Surface, pet: Pet) -> CGFloat? {
        guard let range = horizontalPlacementRange(for: pet, on: source) else { return nil }
        let desired = side.kind == .windowLeft ? side.minX - 40 : side.minX + 40
        return min(max(desired, range.lowerBound), range.upperBound)
    }

    private func windowClimbTargetY(for side: Surface, startY: CGFloat, pet: Pet) -> CGFloat? {
        guard let geometry = pet.contactGeometry else { return nil }
        let facing: Facing = side.kind == .windowLeft ? .right : .left
        let climbAnchorY = pet.animation.definition.clip(named: "climb", facing: facing).clip.anchor.y
        let lowerContact = max(side.minY + geometry.height, startY)
        let upperContact = side.maxY - CGFloat(1 - climbAnchorY) * pet.size.height - 1
        guard upperContact > lowerContact else { return nil }
        // Jump to the middle of the climbable span, leaving a substantial wall section to climb.
        let targetY = lowerContact + (upperContact - lowerContact) * 0.5
        guard targetY >= side.minY + geometry.height,
            targetY >= startY + 48,
            targetY.isFinite
        else { return nil }
        return targetY
    }

    private mutating func attemptWindowReturn(
        _ pet: inout Pet, toward side: WallSide, events: inout [WorldEvent]
    ) {
        guard let source = attachedSurface(of: pet), source.kind == .windowTop,
            let dock = surfaces.surfaces.first(where: { $0.kind == .dockTop }),
            let geometry = pet.contactGeometry, let screen = screens.first,
            let range = horizontalPlacementRange(for: pet, on: dock)
        else {
            pet.windowExcursionPhase = nil
            boundedIdle(&pet, events: &events)
            return
        }
        let jumpOffset = side == .left ? -jumpTuning.maxHorizontalDisplacement : jumpTuning.maxHorizontalDisplacement
        let targetX = min(max(pet.position.x + CGFloat(jumpOffset), range.lowerBound), range.upperBound)
        let target = CGPoint(x: targetX, y: dock.y)
        if abs(targetX - pet.position.x) <= jumpTuning.maxHorizontalDisplacement,
            JumpSolver.solve(
                from: pet.position, target: target, targetSurfaceID: dock.id, surfaces: surfaces,
                geometry: geometry, screen: screen, physics: physics, tuning: jumpTuning,
                visualMargin: pet.edgeMargin) != nil
        {
            requestJump(
                JumpRequest(target: .surface(dock.id, x: targetX), returnActivity: .walking),
                pet: &pet, events: &events)
            if pet.state == .grounded(.preparingJump) { return }
        }

        let edgeX = side == .left ? source.minX + geometry.halfWidth : source.maxX - geometry.halfWidth
        let direction: Facing = pet.position.x > edgeX ? .left : .right
        pet.facing = direction
        pet.animation.setFacing(direction)
        pet.activity = .windowExcursion
        pet.activityDuration = 2
        pet.activityDeadline = time + 2
        enter(.walking, pet: &pet, events: &events)
    }

    private func windowTop(for side: Surface, identity: String, geometry: ContactGeometry) -> Surface? {
        let contactX = side.kind == .windowLeft ? side.minX + geometry.halfWidth : side.minX - geometry.halfWidth
        return surfaces.surfaces.first {
            $0.kind == .windowTop && SurfaceMap.windowIdentity(for: $0.id) == identity
                && $0.y == side.maxY
                && contactX >= $0.minX + geometry.halfWidth && contactX <= $0.maxX - geometry.halfWidth
        }
    }

    private func isClimbable(_ kind: SurfaceKind, on side: WallSide) -> Bool {
        switch (kind, side) {
        case (.screenLeft, .left), (.windowLeft, .left), (.screenRight, .right), (.windowRight, .right): true
        default: false
        }
    }

    private func climbFallVelocityX(side: WallSide, pet: Pet) -> CGFloat {
        if case .climbing(let surfaceID) = pet.windowExcursionPhase {
            if surfaceID.rawValue.contains(":left:") { return -150 }
            if surfaceID.rawValue.contains(":right:") { return 150 }
        }
        return side == .left ? 150 : -150
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
            case .grounded(.idle), .grounded(.sitting), .grounded(.observing), .grounded(.stretching),
                .grounded(.reactingToCursor), .spawning, .recovering, .held:
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
        guard let range = horizontalPlacementRange(for: pet, on: surface) else { return }
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
        guard let range = horizontalPlacementRange(for: pet, on: surface) else { return false }
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
            surface.isUsable
        else { return }
        if surface.isVertical {
            guard let range = verticalRange(for: pet, on: surface) else { return }
            let y = min(max(surface.point(atParameter: attachment.parameter).y, range.lowerBound), range.upperBound)
            pet.position = CGPoint(x: surface.segment.start.x, y: y)
            pet.velocity = .zero
            pet.attachment = SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atY: y))
            return
        }
        guard let geometry = pet.contactGeometry else {
            return
        }
        let requiredHalfWidth =
            surface.kind == .windowTop ? geometry.halfWidth : max(geometry.halfWidth, pet.edgeMargin)
        guard surface.width >= requiredHalfWidth * 2,
            let range = horizontalPlacementRange(for: pet, on: surface)
        else { return }
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
            guard let surface = surfaces.surface(attachment.surfaceID), surface.isUsable else { return nil }
            if surface.isVertical {
                guard case .grounded(.climbing(let side)) = pet.state,
                    isClimbable(surface.kind, on: side),
                    let range = verticalRange(for: pet, on: surface),
                    abs(pet.position.x - surface.segment.start.x) <= physics.contactTolerance,
                    range.contains(pet.position.y)
                else { return nil }
                return surface
            }
            guard let geometry = pet.contactGeometry, surface.width >= geometry.halfWidth * 2,
                pet.position.x >= surface.minX + geometry.halfWidth - physics.contactTolerance,
                pet.position.x <= surface.maxX - geometry.halfWidth + physics.contactTolerance,
                abs(pet.position.y - surface.y) <= physics.contactTolerance
            else { return nil }
            return surface
        }
    }

    private func wall(at position: CGPoint, facing: Facing) -> Surface? {
        let kind: SurfaceKind = facing == .left ? .screenLeft : .screenRight
        return surfaces.surfaces.first {
            $0.kind == kind && $0.isVertical && $0.minY <= position.y && position.y <= $0.maxY
        }
    }

    /// The contact point moves far enough from either end that the climbing canvas remains in the hosted frame.
    private func verticalRange(for pet: Pet, on wall: Surface, anchorY: CGFloat? = nil) -> ClosedRange<CGFloat>? {
        let anchorY = anchorY ?? CGFloat(pet.animation.currentFrame.anchor.y)
        let size = pet.size.height
        let lower = wall.minY + anchorY * size
        let upper = wall.maxY - (1 - anchorY) * size
        return lower <= upper ? lower...upper : nil
    }

    private func placementSurface(for pet: Pet) -> Surface? {
        guard let geometry = pet.contactGeometry else { return nil }
        func usable(_ surface: Surface) -> Bool {
            let requiredHalfWidth =
                surface.kind == .windowTop
                ? geometry.halfWidth : max(geometry.halfWidth, pet.edgeMargin)
            guard surface.isUsable, surface.width >= requiredHalfWidth * 2 else { return false }
            let onHostedScreen =
                screens.isEmpty
                || screens.contains {
                    surface.y >= $0.frame.minY && surface.y < $0.frame.maxY
                        && surface.maxX > $0.frame.minX && surface.minX < $0.frame.maxX
                }
            return onHostedScreen
                && (surface.kind != .windowTop || horizontalPlacementRange(for: pet, on: surface) != nil)
        }
        return surfaces.surfaces.first { $0.kind == .dockTop && usable($0) }
            ?? surfaces.surfaces.first { $0.kind == .windowTop && usable($0) }
            ?? surfaces.surfaces.first { usable($0) }
    }

    private func horizontalPlacementRange(for pet: Pet, on surface: Surface) -> ClosedRange<CGFloat>? {
        guard let geometry = pet.contactGeometry else { return nil }
        let supportMargin = surface.kind == .windowTop ? geometry.halfWidth : max(geometry.halfWidth, pet.edgeMargin)
        let supportRange = surface.walkableRange(margin: supportMargin)
        guard surface.kind == .windowTop else { return supportRange }
        let visibleRange = visualRange(for: pet)
        let lower = max(supportRange.lowerBound, visibleRange.lowerBound)
        let upper = min(supportRange.upperBound, visibleRange.upperBound)
        return lower <= upper ? lower...upper : nil
    }

    // MARK: - Transitions and invariants

    /// Changes pose anchors without shifting the rendered body, keeping walk↔climb and climb↔fall continuous.
    private func enterPreservingSpriteRect(
        _ state: PetState, facing: Facing?, pet: inout Pet, events: inout [WorldEvent]
    ) {
        let previous = pet.animation.currentFrame
        let size = pet.size
        let previousAnchorX = previous.mirrored ? 1 - previous.anchor.x : previous.anchor.x
        if let facing {
            pet.facing = facing
            pet.animation.setFacing(facing)
        }
        enter(state, pet: &pet, events: &events)
        let current = pet.animation.currentFrame
        let currentAnchorX = current.mirrored ? 1 - current.anchor.x : current.anchor.x
        pet.position.x += CGFloat(currentAnchorX - previousAnchorX) * size.width
        pet.position.y += CGFloat(current.anchor.y - previous.anchor.y) * size.height
    }

    private func enter(_ state: PetState, pet: inout Pet, events: inout [WorldEvent]) {
        let previous = pet.state.kind
        pet.state = state
        pet.stateElapsed = 0
        let clip: String?
        switch state {
        case .grounded(.walking): clip = BehaviorTuning.walkClip
        case .grounded(.climbing): clip = "climb"
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
        case .grounded(.reactingToCursor), .grounded(.reactingToClick): clip = reduceMotion ? "idle" : "curious"
        case .held: clip = pet.heldPickupPresentationActive ? "picked-up" : "held"
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
        case .grounded, .airborne, .held: break
        }
        let invalidContact: Bool
        switch pet.state {
        case .airborne: invalidContact = pet.attachment != nil
        case .grounded: invalidContact = pet.attachment == nil
        case .held: invalidContact = pet.attachment != nil
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
            case .held: return true
            case .grounded, .airborne: return surfaces.surfaces.contains { $0.isUsable }
            }
        }
    }

    public var needsAnimationFrames: Bool {
        surfaces.surfaces.contains { $0.isUsable } && pets.contains { isAnimating($0) }
    }

    private func isAnimating(_ pet: Pet) -> Bool {
        switch pet.state {
        case .grounded(.walking), .grounded(.climbing): return true
        case .grounded(.landing), .grounded(.idle), .grounded(.preparingJump), .airborne:
            return pet.animation.definition.clips[pet.animation.requestedClip] != nil
                && pet.animation.rate > 0 && !pet.animation.player.isFinished
        case .held:
            return pet.animation.definition.clips[pet.animation.requestedClip] != nil
                && pet.animation.rate > 0 && !pet.animation.player.isFinished
        case .grounded(.sittingDown), .grounded(.sitting), .grounded(.standingUp), .grounded(.lyingDown),
            .grounded(.sleeping), .grounded(.wakingUp), .grounded(.stretching), .grounded(.observing),
            .grounded(.reactingToCursor), .grounded(.reactingToClick):
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
                    isVisible: pet.attachment != nil || { if case .airborne = pet.state { true } else { false } }()
                        || pet.state == .held,
                    isAnimating: isAnimating(pet)))
        }
    }

    public func snapshot() -> RenderSnapshot {
        var snapshot = RenderSnapshot()
        writeSnapshot(into: &snapshot)
        return snapshot
    }
}
