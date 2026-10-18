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
    public var tuning: BehaviorTuning

    private var random: any RandomSource
    private var nextPetID = 1
    /// Reused per step so stepping does not allocate.
    private var animationEvents: [AnimationEvent] = []

    public init(tuning: BehaviorTuning = BehaviorTuning(), random: any RandomSource) {
        self.tuning = tuning
        self.random = random
        animationEvents.reserveCapacity(8)
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
    }

    // MARK: - Environment

    /// Applies an environment change now (between steps). Attached pets are re-projected onto moved surfaces
    /// by their parameter and kept inside the walkable range; pets whose surface disappeared are recovered on
    /// their next step; unplaced pets are placed when a surface appears.
    public mutating func apply(_ input: WorldInput) {
        switch input {
        case .screens(let screens):
            self.screens = screens
        case .surfaces(let newSurfaces):
            let changes = surfaces.changes(to: newSurfaces)
            guard !changes.isEmpty else { return }
            surfaces.apply(changes)
            var events: [WorldEvent] = []
            for index in pets.indices {
                var pet = pets[index]
                if pet.attachment == nil {
                    if pet.state == .spawning { place(&pet, events: &events) }
                } else {
                    reproject(&pet)
                }
                pets[index] = pet
            }
        }
    }

    // MARK: - Step

    /// Advances every pet by one fixed step and appends what happened to `events` (not cleared first).
    public mutating func step(dt: Double, into events: inout [WorldEvent]) {
        guard dt.isFinite, dt > 0 else { return }
        time += dt
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
        pet.stateElapsed += dt
        switch pet.state {
        case .spawning:
            if pet.attachment == nil { place(&pet, events: &events) }
            if pet.attachment != nil { enter(.walking, pet: &pet, events: &events) }
        case .walking:
            guard let surface = attachedSurface(of: pet) else {
                return recover(&pet, reason: .surfaceLost, events: &events)
            }
            let reachedEdge = walk(&pet, on: surface, dt: dt)
            advanceAnimation(of: &pet, dt: dt, events: &events)
            if reachedEdge {
                events.append(.edgeReached(pet.id))
                enter(.turning(to: pet.facing.opposite), pet: &pet, events: &events)
            }
        case .turning(let newFacing):
            guard attachedSurface(of: pet) != nil else {
                return recover(&pet, reason: .surfaceLost, events: &events)
            }
            // The walk clip holds its current frame while turning (not advanced).
            if pet.stateElapsed + FixedStepAccumulator.tolerance >= tuning.turnHold {
                pet.facing = newFacing
                pet.animation.setFacing(newFacing)
                enter(.walking, pet: &pet, events: &events)
            }
        case .recovering(let reason):
            enter(.spawning, pet: &pet, events: &events)
            if reason != .surfaceLost || !resettle(&pet, events: &events) {
                place(&pet, events: &events)
            }
        }
        validate(&pet, events: &events)
    }

    /// Moves the pet along `surface` in its facing direction; returns whether it reached the walkable end
    /// (the contact point is then clamped to that end, so the sprite never passes the surface end).
    private func walk(_ pet: inout Pet, on surface: Surface, dt: Double) -> Bool {
        let nominalSpeed = pet.animation.player.clip.nominalSpeed ?? tuning.fallbackWalkSpeed
        let speed = CGFloat(nominalSpeed * tuning.speedScale * pet.scale)
        let range = surface.walkableRange(margin: pet.edgeMargin)
        var x = pet.position.x + (pet.facing == .right ? speed : -speed) * CGFloat(dt)
        var reachedEdge = false
        if pet.facing == .right, x >= range.upperBound {
            x = range.upperBound
            reachedEdge = true
        } else if pet.facing == .left, x <= range.lowerBound {
            x = range.lowerBound
            reachedEdge = true
        }
        setPosition(of: &pet, x: x, on: surface)
        return reachedEdge
    }

    private mutating func advanceAnimation(of pet: inout Pet, dt: Double, events: inout [WorldEvent]) {
        animationEvents.removeAll(keepingCapacity: true)
        pet.animation.advance(by: dt, into: &animationEvents)
        for event in animationEvents {
            events.append(.animationEvent(pet.id, event))
        }
    }

    // MARK: - Placement

    /// Puts an unplaced pet on the spawn surface at a random position and facing, walk clip at frame 0.
    private mutating func place(_ pet: inout Pet, events: inout [WorldEvent]) {
        guard let surface = surfaces.spawnSurface else { return }
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

    /// After `surfaceLost` (the Dock hidden, shown or moved to a side, T6.4): puts the pet on the spawn surface
    /// straight below or above its last position, keeping facing and animation, when that surface spans its x
    /// (clamped into the walkable range). Returns `false` when it does not, so the pet respawns at random.
    private func resettle(_ pet: inout Pet, events: inout [WorldEvent]) -> Bool {
        let x = pet.position.x
        guard let surface = surfaces.spawnSurface, x.isFinite, surface.minX <= x, x <= surface.maxX else {
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
        guard let attachment = pet.attachment, let surface = surfaces.surface(attachment.surfaceID) else { return }
        let range = surface.walkableRange(margin: pet.edgeMargin)
        let x = min(max(surface.point(atParameter: attachment.parameter).x, range.lowerBound), range.upperBound)
        setPosition(of: &pet, x: x, on: surface)
    }

    private func setPosition(of pet: inout Pet, x: CGFloat, on surface: Surface) {
        pet.position = CGPoint(x: x, y: surface.y)
        pet.attachment = SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atX: x))
    }

    private func attachedSurface(of pet: Pet) -> Surface? {
        pet.attachment.flatMap { surfaces.surface($0.surfaceID) }
    }

    // MARK: - Transitions and invariants

    private func enter(_ state: PetState, pet: inout Pet, events: inout [WorldEvent]) {
        let previous = pet.state.kind
        pet.state = state
        pet.stateElapsed = 0
        if previous != state.kind {
            events.append(.stateChanged(pet.id, from: previous, to: state.kind))
        }
    }

    private func recover(_ pet: inout Pet, reason: RecoveryReason, events: inout [WorldEvent]) {
        pet.attachment = nil
        enter(.recovering(reason), pet: &pet, events: &events)
        events.append(.recovered(pet.id, reason: reason))
    }

    /// Recovers a placed pet whose position is not finite or outside every screen (with margin).
    private func validate(_ pet: inout Pet, events: inout [WorldEvent]) {
        guard pet.attachment != nil else { return }
        if !pet.position.x.isFinite || !pet.position.y.isFinite {
            recover(&pet, reason: .invalidNumbers, events: &events)
        } else if !screens.isEmpty {
            let margin = tuning.outOfBoundsMargin
            let isOnSomeScreen = screens.contains {
                $0.frame.insetBy(dx: -margin, dy: -margin).contains(pet.position)
            }
            if !isOnSomeScreen { recover(&pet, reason: .outOfBounds, events: &events) }
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
                    frame: pet.animation.currentFrame, isVisible: pet.attachment != nil))
        }
    }

    public func snapshot() -> RenderSnapshot {
        var snapshot = RenderSnapshot()
        writeSnapshot(into: &snapshot)
        return snapshot
    }
}
