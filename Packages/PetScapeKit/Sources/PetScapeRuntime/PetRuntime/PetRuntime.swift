import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRendering

/// Owns the simulation and connects it to the overlay (modules.md, data-flow.md#per-frame-pipeline):
///
/// display frame → fixed steps of `PetWorld` → snapshot → `PetRenderer` (layers) → `PetHitTester` → the
/// coordinator's pass-through update. Frames run while the run state is `running` and a visible pet animates,
/// or while an unplaced pet needs a recovery/placement step on an available surface. Pausing, hiding and
/// suspension stop the display link, and the accumulator is reset so resuming never catches up (ADR-0013).
///
/// Walkway (M6): the Dock top on the Dock's screen, or the screen bottom when the Dock is hidden or on a side
/// (`DockSurfaceProvider`). Pause, hide and the Dock offset are persisted through `PreferencesStore` (FR-18).
public final class PetRuntime {
    public let overlay: OverlayCoordinator

    private let preferences: any PreferencesStore
    private let hitTester: PetHitTester
    private var world: PetWorld
    private var accumulator = FixedStepAccumulator()
    private var character: LoadedCharacter?
    private var renderer: PetRenderer?
    private weak var rendererView: OverlayContentView?
    /// Reused every frame (no per-frame allocation once warm).
    private var snapshot = RenderSnapshot()
    private var events: [WorldEvent] = []
    #if DEBUG
        private var frameRateWindow = FrameRateWindow()
    #endif

    public init(
        screenProvider: ScreenProvider,
        cursorSampler: CursorSampler,
        systemEvents: SystemEventsMonitor,
        fullScreenDetector: FullScreenSpaceDetector,
        preferences: any PreferencesStore,
        overlays: OverlayWindowManager = OverlayWindowManager(),
        makeFrameDriver: @escaping (NSView) -> any FrameDriver = { DisplayLinkFrameDriver(view: $0) },
        random: any RandomSource = SystemRandomNumberGenerator(),
        tuning: BehaviorTuning = BehaviorTuning()
    ) {
        let hitTester = PetHitTester()
        self.hitTester = hitTester
        self.preferences = preferences
        world = PetWorld(tuning: tuning, random: random)
        world.apply(.configureBehavior(preferences.petSettings.behavior))
        world.apply(.setSpeedScale(preferences.petSettings.speed))
        events.reserveCapacity(16)
        overlay = OverlayCoordinator(
            screenProvider: screenProvider, cursorSampler: cursorSampler, systemEvents: systemEvents,
            fullScreenDetector: fullScreenDetector, overlays: overlays,
            runState: RunStateController(intent: preferences.userIntent),
            dock: DockSurfaceProvider(offsetAdjustment: preferences.dockOffsetAdjustment), hitTester: hitTester,
            makeFrameDriver: makeFrameDriver)
    }

    /// Pause and hide as the user last chose them (restored from preferences at launch).
    public var userIntent: UserIntent { overlay.runState.intent }

    /// The current simulation state (tests, debugging).
    public var currentSnapshot: RenderSnapshot { snapshot }
    public var pets: [Pet] { world.pets }
    public var simulationTime: Double { world.time }
    public var petSettings: PetSettings { preferences.petSettings }
    public var onUserIntentChange: ((UserIntent) -> Void)?

    /// Applies persisted choices between fixed steps, including while paused or hidden.
    public func setPetSettings(_ settings: PetSettings) {
        preferences.petSettings = settings
        world.apply(.setDisplayScale(settings.scale))
        world.apply(.setSpeedScale(settings.speed))
        world.apply(.configureBehavior(settings.behavior))
        accumulator.reset()
        renderNow()
    }

    public func wakePet() {
        for pet in world.pets { world.apply(.wake(pet.id)) }
        accumulator.reset()
        renderNow()
    }

    public func start() {
        overlay.onFrame = { [weak self] timestamp in self?.frame(timestamp) }
        overlay.onScreensChange = { [weak self] in self?.screensDidChange() }
        overlay.onStatusChange = { [weak self] status in self?.statusDidChange(status) }
        overlay.onFrameDriverChange = { [weak self] _ in self?.accumulator.reset() }
        overlay.onMouseEvent = { [weak self] event in self?.handle(event) }
        overlay.needsFrames = false
        overlay.start()
        Log.simulation.notice(
            "Pet runtime started: paused=\(self.userIntent.isPaused, privacy: .public) hidden=\(self.userIntent.isHidden, privacy: .public)"
        )
    }

    /// Stops frames, observers and overlays (FR-13) and drops the pet layers.
    public func stop() {
        overlay.stop()
        renderer?.removeAll()
        renderer = nil
        hitTester.removeAll()
        accumulator.reset()
    }

    // MARK: - User intents (FR-02, FR-11, FR-12, FR-18)

    public func setPaused(_ paused: Bool) {
        preferences.isPaused = paused
        overlay.runState.setPaused(paused)
        onUserIntentChange?(userIntent)
    }

    public func setHidden(_ hidden: Bool) {
        preferences.isHidden = hidden
        overlay.runState.setHidden(hidden)
        onUserIntentChange?(userIntent)
    }

    /// Explicit movement commands retain their independent physical guards alongside autonomy.
    @discardableResult
    public func requestJump(_ request: JumpRequest) -> Bool {
        guard overlay.runState.status.state == .running, let id = snapshot.pets.first?.id else { return false }
        let previous = world.pet(id)?.state
        world.apply(.requestJump(id, request))
        let accepted =
            previous != .grounded(.preparingJump)
            && world.pet(id)?.state == .grounded(.preparingJump)
        renderNow()
        return accepted
    }

    /// A target-only debug intent preserves the current activity across landing.
    @discardableResult
    public func requestJump(to target: JumpRequest.Target) -> Bool {
        guard let activity = world.pets.first?.resumeActivity else { return false }
        return requestJump(JumpRequest(target: target, returnActivity: activity))
    }

    public func setActivity(_ activity: ResumeActivity) {
        guard overlay.runState.status.state == .running, let id = snapshot.pets.first?.id else { return }
        world.apply(.setActivity(id, activity))
        renderNow()
    }

    /// Points added to the estimated Dock top (T6.3; DEBUG menu in the MVP, Settings › Advanced in M9).
    public var dockOffsetAdjustment: Double { overlay.dock.offsetAdjustment }

    /// Stores the offset (clamped to −40…+40 pt) and moves the walkway; an attached pet follows it.
    public func setDockOffsetAdjustment(_ offset: Double) {
        preferences.dockOffsetAdjustment = offset
        overlay.dock.offsetAdjustment = preferences.dockOffsetAdjustment
        applySurfaces()
        renderNow()
    }

    // MARK: - Character

    /// Puts one pet of `character` into the world (replacing any previous one) and shows it, even while paused.
    public func show(_ character: LoadedCharacter) {
        self.character = character
        world.removeAllPets()
        let id = world.spawn(character.definition, scale: preferences.petSettings.scale)
        let placement = world.pet(id)?.attachment.map { "on \($0.surfaceID)" } ?? "waiting for a surface"
        Log.simulation.notice(
            "Pet \(id, privacy: .public) '\(character.definition.id.rawValue, privacy: .public)' spawned \(placement, privacy: .public)"
        )
        renderNow()
    }

    // MARK: - Overlay callbacks

    private func screensDidChange() {
        world.apply(.screens(overlay.hostScreen.map { [$0] } ?? []))
        applySurfaces()
        let view = overlay.hostContentView
        if view !== rendererView {
            renderer?.removeAll()
            renderer = view.map { PetRenderer(hostLayer: $0.petLayerHost) }
            rendererView = view
        }
        renderNow()
    }

    /// The Dock walkway as the world's surface set: a moved Dock keeps its surface (the pet rides it, clamped);
    /// a Dock hidden, shown or moved to a side replaces it (the pet re-settles below or above, T6.4).
    private func applySurfaces() {
        let floors = SurfaceMap.screenBottoms(for: overlay.hostScreen.map { [$0] } ?? [])
        var surfaces = overlay.dock.surfaces
        for floor in floors where !surfaces.contains(where: { $0.id == floor.id }) {
            surfaces.append(floor)
        }
        world.apply(.surfaces(surfaces))
        #if DEBUG
            updateSurfaceDebugLine()
        #endif
    }

    private func statusDidChange(_ status: RunStatus) {
        // Frames stopped: the next frame after they resume only records its timestamp (no catch-up).
        if !status.isFrameDriverRunning { accumulator.reset() }
    }

    private func frame(_ timestamp: TimeInterval) {
        let passive = isPassiveSleep
        let steps = accumulator.steps(forFrameAt: timestamp, allowPassiveCatchUp: passive)
        #if DEBUG
            var executedSteps = 0
            // A zero-step seed is still a delivered frame; passive work may stop before its budget.
            defer { frameRateWindow.record(timestamp: timestamp, steps: executedSteps) }
        #endif
        guard steps > 0 else { return }
        events.removeAll(keepingCapacity: true)
        for _ in 0..<steps {
            Signposts.measure(Signposts.Interval.simulationStep) {
                world.step(dt: accumulator.step, into: &events)
            }
            #if DEBUG
                executedSteps += 1
            #endif
            // A passive batch may hit a wake deadline or lose support. Drop its remaining ticks,
            // so movement resumes on the next ordinary display frame, never in a low-rate burst.
            if passive && !isPassiveSleep { break }
        }
        if !events.isEmpty { log(events) }
        renderNow()
    }

    private var isPassiveSleep: Bool {
        !world.pets.isEmpty && world.pets.allSatisfy { $0.state == .grounded(.sleeping) }
    }

    /// Snapshot → layers → hit masks; also keep frames on for a pending placement or recovery step.
    private func renderNow() {
        events.removeAll(keepingCapacity: true)
        world.drainEvents(into: &events)
        if !events.isEmpty { log(events) }
        world.writeSnapshot(into: &snapshot)
        if let renderer, let converter = overlay.converter, let screen = overlay.hostScreen {
            renderer.render(snapshot, converter: converter, screen: screen) { pet in
                character?.frame(pet.frame)?.image
            }
        }
        hitTester.update(snapshot) { pet in character?.frame(pet.frame)?.hitMask }
        let demand = world.needsSimulationSteps || world.needsAnimationFrames
        overlay.preferredFramesPerSecond = world.pets.isEmpty ? 60 : world.preferredFramesPerSecond
        if !demand || demand != overlay.needsFrames { accumulator.reset() }
        overlay.needsFrames = demand
    }

    #if DEBUG
        /// Actual step input to the latest frame-rate diagnostic sample (including a zero-step seed).
        var lastFrameStepCount: Int? { frameRateWindow.lastSampleSteps }

        /// DEBUG menu "Show walkway": a line where the paws should be (surface y, overlay-local).
        public var showsWalkway = false {
            didSet { updateSurfaceDebugLine() }
        }

        private func updateSurfaceDebugLine() {
            let view = overlay.hostContentView
            guard let surface = overlay.dock.surface, let screen = overlay.hostScreen, showsWalkway else {
                view?.debugWalkwayY = nil
                return
            }
            view?.debugWalkwayY = surface.y - screen.frame.minY
        }
    #endif

    private func handle(_ event: OverlayMouseEvent) {
        #if DEBUG
            guard event.kind == .down else { return }
            // AC-M5-02: a click that reached the overlay landed on the pet's opaque pixels.
            let pet = hitTester.petID(at: event.location).map(\.description) ?? "none"
            Log.simulation.debug(
                "Mouse down on pet \(pet, privacy: .public) at (\(event.location.x, format: .fixed(precision: 1), privacy: .public), \(event.location.y, format: .fixed(precision: 1), privacy: .public))"
            )
        #endif
    }

    /// State changes and recoveries; per-frame animation events (footsteps) are not logged.
    private func log(_ events: [WorldEvent]) {
        for event in events {
            switch event {
            case .stateChanged(let id, let from, let to):
                Log.simulation.debug(
                    "Pet \(id, privacy: .public): \(from.rawValue, privacy: .public) → \(to.rawValue, privacy: .public)"
                )
            case .edgeReached(let id):
                Log.simulation.debug("Pet \(id, privacy: .public) reached an edge")
            case .placed(let id, let surface):
                Log.simulation.info("Pet \(id, privacy: .public) placed on \(surface, privacy: .public)")
            case .recovered(let id, let reason):
                Log.simulation.error("Pet \(id, privacy: .public) recovered: \(reason.rawValue, privacy: .public)")
            case .surfaceLost(let id, let surface):
                Log.simulation.info("Pet \(id, privacy: .public) lost surface \(surface, privacy: .public)")
            case .landed(let id, let surface):
                Log.simulation.debug("Pet \(id, privacy: .public) landed on \(surface, privacy: .public)")
            case .tookOff(let id):
                Log.simulation.debug("Pet \(id, privacy: .public) took off")
            case .apex(let id):
                Log.simulation.debug("Pet \(id, privacy: .public) reached jump apex")
            case .jumpRejected(let id, let reason):
                Log.simulation.debug("Pet \(id, privacy: .public) jump rejected: \(reason.rawValue, privacy: .public)")
            case .jumpCancelled(let id):
                Log.simulation.info("Pet \(id, privacy: .public) jump cancelled after environment change")
            case .animationEvent:
                break
            }
        }
    }
}

#if DEBUG
    /// DEBUG evidence for T5.7: the delivered frame rate and steps per second while frames run, logged every
    /// 10 s of continuous frames (a gap of more than 0.5 s starts a new window).
    private struct FrameRateWindow {
        private var start: TimeInterval?
        private var last: TimeInterval = 0
        private var frames = 0
        private var steps = 0
        private(set) var lastSampleSteps: Int?

        mutating func record(timestamp: TimeInterval, steps newSteps: Int) {
            lastSampleSteps = newSteps
            guard let start, timestamp - last <= 0.5 else {
                restart(at: timestamp)
                return
            }
            frames += 1
            steps += newSteps
            last = timestamp
            let elapsed = timestamp - start
            guard elapsed >= 10 else { return }
            let framesPerSecond = Double(frames) / elapsed
            let stepsPerSecond = Double(steps) / elapsed
            Log.performance.debug(
                "Frames: \(framesPerSecond, format: .fixed(precision: 1), privacy: .public) fps, \(stepsPerSecond, format: .fixed(precision: 1), privacy: .public) steps/s over \(elapsed, format: .fixed(precision: 1), privacy: .public) s"
            )
            restart(at: timestamp)
        }

        private mutating func restart(at timestamp: TimeInterval) {
            start = timestamp
            last = timestamp
            frames = 0
            steps = 0
        }
    }
#endif
