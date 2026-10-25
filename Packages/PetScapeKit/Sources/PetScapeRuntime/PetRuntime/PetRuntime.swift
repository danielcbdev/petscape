import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRendering

public struct PetDanceAvailability: Equatable, Sendable {
    public let canDance: Bool
    public let canStopDance: Bool
    public let specialArtworkPending: Bool

    public init(canDance: Bool, canStopDance: Bool, specialArtworkPending: Bool) {
        self.canDance = canDance
        self.canStopDance = canStopDance
        self.specialArtworkPending = specialArtworkPending
    }
}

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

    private let musicDetector: MusicDetectionController
    private var isStarted = false
    public var onMusicStatusChange: ((MusicDetectionStatus) -> Void)?
    public var onDanceAvailabilityChange: ((Bool) -> Void)?
    public var onStopDanceAvailabilityChange: ((Bool) -> Void)?
    public var onPetDanceAvailabilityChange: (([PetID: PetDanceAvailability]) -> Void)?
    private var publishedDanceAvailability = false
    private var publishedStopDanceAvailability = false
    private var publishedPetDanceAvailability: [PetID: PetDanceAvailability] = [:]
    private let preferences: any PreferencesStore
    private let windowTracker: CompositeWindowTracker
    private let hitTester: PetHitTester
    private var world: PetWorld
    private lazy var interactionController = InteractionController(
        hitTest: { [weak self] location in self?.hitTester.petID(at: location) },
        footPosition: { [weak self] id in self?.snapshot.pets.first(where: { $0.id == id })?.position },
        submit: { [weak self] id, command in self?.submitInteraction(id, command: command) ?? false },
        setCapture: { [weak self] id in self?.overlay.setInteractionCapture(id) }
    )
    private var accumulator = FixedStepAccumulator()
    private var charactersByPetID: [PetID: LoadedCharacter] = [:]
    private(set) var behaviorFamilyTasks: [PetID: [String: Task<Void, Never>]] = [:]
    private var renderers: [ScreenID: PetRenderer] = [:]
    private var rendererViews: [ScreenID: OverlayContentView] = [:]
    private var screenSnapshots: [ScreenID: RenderSnapshot] = [:]
    /// Reused every frame (no per-frame allocation once warm).
    private var snapshot = RenderSnapshot()
    private var events: [WorldEvent] = []
    private var windowSurfacesForWorld: [Surface] = []
    private var lastWindowSnapshotTime: TimeInterval?
    private var lastTrackedWindows: [TrackedWindow] = []
    public private(set) var trackedWindowSurfaces: [Surface] = []
    public var onTrackedWindowSurfacesChange: (([Surface]) -> Void)?
    public var onWindowPermissionRevoked: (() -> Void)?
    public var onCharacterIssuesChange: ((PetID, [ManifestIssue]) -> Void)?
    #if DEBUG
        private var frameRateWindow = FrameRateWindow()
    #endif

    public init(
        screenProvider: ScreenProvider,
        cursorSampler: CursorSampler,
        systemEvents: SystemEventsMonitor,
        fullScreenDetector: FullScreenSpaceDetector,
        preferences: any PreferencesStore,
        windowTracker: CompositeWindowTracker = CompositeWindowTracker(),
        musicDetector: MusicDetectionController = MusicDetectionController(),
        overlays: OverlayWindowManager = OverlayWindowManager(),
        makeFrameDriver: @escaping (NSView) -> any FrameDriver = { DisplayLinkFrameDriver(view: $0) },
        random: any RandomSource = SystemRandomNumberGenerator(),
        tuning: BehaviorTuning = BehaviorTuning()
    ) {
        let hitTester = PetHitTester()
        self.hitTester = hitTester
        self.preferences = preferences
        self.musicDetector = musicDetector
        self.windowTracker = windowTracker
        world = PetWorld(tuning: tuning, random: random)
        world.apply(.configureBehavior(preferences.petSettings.behavior))
        world.apply(.setSpeedScale(preferences.petSettings.speed))
        world.apply(.setCursorReactionsEnabled(preferences.petSettings.interaction.cursorReactionsEnabled))
        events.reserveCapacity(16)
        overlay = OverlayCoordinator(
            screenProvider: screenProvider, cursorSampler: cursorSampler, systemEvents: systemEvents,
            fullScreenDetector: fullScreenDetector, overlays: overlays,
            runState: RunStateController(intent: preferences.userIntent),
            dock: DockSurfaceProvider(offsetAdjustment: preferences.dockOffsetAdjustment), hitTester: hitTester,
            makeFrameDriver: makeFrameDriver)
        overlay.directInteractionsEnabled = preferences.petSettings.interaction.directInteractionEnabled
        windowTracker.onChange = { [weak self] windows in
            self?.receiveTrackedWindows(windows)
        }
        windowTracker.onPermissionRevoked = { [weak self] in self?.onWindowPermissionRevoked?() }
        musicDetector.onMusicChange = { [weak self] playing in
            guard let self else { return }
            self.world.apply(.setMusicPlaying(playing))
            self.renderNow()
        }
        musicDetector.onStatusChange = { [weak self] status in self?.onMusicStatusChange?(status) }
    }

    /// Pause and hide as the user last chose them (restored from preferences at launch).
    public var userIntent: UserIntent { overlay.runState.intent }

    /// The current simulation state (tests, debugging).
    public var currentSnapshot: RenderSnapshot { snapshot }
    public var pets: [Pet] { world.pets }
    public var hasPlaceholderCharacter: Bool { charactersByPetID.values.contains(where: \.isPlaceholder) }
    public var hasDegradedCharacter: Bool { charactersByPetID.values.contains(where: \.isDegraded) }
    public func loadedCharacter(for id: PetID) -> LoadedCharacter? { charactersByPetID[id] }
    public var simulationTime: Double { world.time }
    public var petSettings: PetSettings { preferences.petSettings }
    public var onUserIntentChange: ((UserIntent) -> Void)?

    /// Applies persisted choices between fixed steps, including while paused or hidden.
    public func setPetSettings(_ settings: PetSettings) {
        interactionController.cancel(.settingsChanged)
        preferences.petSettings = settings
        world.apply(.setDisplayScale(settings.scale))
        world.apply(.setSpeedScale(settings.speed))
        world.apply(.configureBehavior(settings.behavior))
        world.apply(.setCursorReactionsEnabled(settings.interaction.cursorReactionsEnabled))
        overlay.directInteractionsEnabled = settings.interaction.directInteractionEnabled
        accumulator.reset()
        renderNow()
    }

    public var musicStatus: MusicDetectionStatus { musicDetector.status }

    public var canDance: Bool { uniquePetID.map { canDance(for: $0) } ?? false }

    public var canStopDance: Bool { uniquePetID.map { canStopDance(for: $0) } ?? false }

    public func stopDance() {
        guard let id = uniquePetID else { return }
        stopDance(for: id)
    }

    public var isSpecialArtworkPending: Bool {
        guard let id = uniquePetID else { return true }
        return isSpecialArtworkPending(for: id)
    }

    public func isSpecialArtworkPending(for id: PetID) -> Bool {
        guard let definition = world.pet(id)?.animation.definition else { return true }
        return definition.clips["dance"] == nil || definition.clips["cleanup"] == nil
    }

    public func requestDance() {
        guard let id = uniquePetID else { return }
        requestDance(for: id)
    }

    public func canDance(for id: PetID) -> Bool {
        overlay.runState.status.state == .running && world.canDance(id)
    }

    public func canStopDance(for id: PetID) -> Bool {
        guard overlay.runState.status.state == .running, let pet = world.pet(id),
            case .grounded(.dancing) = pet.state
        else { return false }
        return true
    }

    public func stopDance(for id: PetID) {
        guard canStopDance(for: id) else { return }
        world.apply(.stopDance(id))
        renderNow()
    }

    public func requestDance(for id: PetID) {
        guard canDance(for: id) else { return }
        world.apply(.requestDance(id))
        renderNow()
    }

    private var uniquePetID: PetID? { world.pets.count == 1 ? world.pets[0].id : nil }

    public func setMusicDancingEnabled(_ enabled: Bool) {
        preferences.isMusicDancingEnabled = enabled
        refreshMusicDetection()
        renderNow()
    }

    public func refreshMusicDetection() {
        let canRun = canRunMusicDetection
        world.apply(.configureMusicDancing(preferences.isMusicDancingEnabled && canRun))
        musicDetector.update(enabled: preferences.isMusicDancingEnabled, canRun: canRun)
    }

    /// Recreates the capture after an explicit recovery action without changing the user's opt-in.
    public func retryMusicDetection() {
        let canRun = canRunMusicDetection
        world.apply(.configureMusicDancing(preferences.isMusicDancingEnabled && canRun))
        musicDetector.retry(enabled: preferences.isMusicDancingEnabled, canRun: canRun)
    }

    /// An app-activation recovery path for capture failures; healthy monitoring is left untouched.
    public func retryUnavailableMusicDetection() {
        guard preferences.isMusicDancingEnabled, musicDetector.status == .unavailable else { return }
        retryMusicDetection()
    }

    private var canRunMusicDetection: Bool {
        isStarted && overlay.runState.status.state == .running
            && preferences.petSettings.behavior.isEnabled && snapshot.pets.contains(where: { $0.isVisible })
    }

    private func publishDanceAvailability() {
        let petAvailability = Dictionary(
            uniqueKeysWithValues: world.pets.map { pet in
                (
                    pet.id,
                    PetDanceAvailability(
                        canDance: canDance(for: pet.id), canStopDance: canStopDance(for: pet.id),
                        specialArtworkPending: isSpecialArtworkPending(for: pet.id))
                )
            })
        if publishedPetDanceAvailability != petAvailability {
            publishedPetDanceAvailability = petAvailability
            onPetDanceAvailabilityChange?(petAvailability)
        }
        let available = canDance
        if publishedDanceAvailability != available {
            publishedDanceAvailability = available
            onDanceAvailabilityChange?(available)
        }
        let stoppable = canStopDance
        if publishedStopDanceAvailability != stoppable {
            publishedStopDanceAvailability = stoppable
            onStopDanceAvailabilityChange?(stoppable)
        }
    }

    public func wakePet() {
        for pet in world.pets { world.apply(.wake(pet.id)) }
        accumulator.reset()
        renderNow()
    }

    public func start() {
        isStarted = true
        overlay.onFrame = { [weak self] timestamp in self?.frame(timestamp) }
        overlay.onScreensChange = { [weak self] in self?.screensDidChange() }
        overlay.onStatusChange = { [weak self] status in self?.statusDidChange(status) }
        overlay.onFrameDriverChange = { [weak self] _ in self?.accumulator.reset() }
        overlay.onMouseEvent = { [weak self] event in
            self?.handle(event)
            self?.interactionController.handle(event)
        }
        overlay.onWillInvalidateInteraction = { [weak self] reason in
            self?.interactionController.cancel(reason)
        }
        overlay.onCursorSample = { [weak self] sample in
            self?.interactionController.update(with: sample)
            self?.world.apply(.setCursorLocation(sample.location))
        }
        overlay.onReduceMotionChange = { [weak self] enabled in
            self?.world.apply(.setReduceMotion(enabled))
            self?.renderNow()
        }
        overlay.needsFrames = false
        overlay.start()
        Log.simulation.notice(
            "Pet runtime started: paused=\(self.userIntent.isPaused, privacy: .public) hidden=\(self.userIntent.isHidden, privacy: .public)"
        )
    }

    /// Stops frames, observers and overlays (FR-13) and drops the pet layers.
    public func stop() {
        isStarted = false
        charactersByPetID.removeAll()
        world.removeAllPets()
        snapshot.pets.removeAll(keepingCapacity: true)
        events.removeAll(keepingCapacity: true)
        world.apply(.suspendMusicBehaviors)
        musicDetector.stop()
        windowTracker.stop()
        overlay.stop()
        renderers.values.forEach { $0.removeAll() }
        renderers.removeAll()
        rendererViews.removeAll()
        screenSnapshots.removeAll()
        hitTester.removeAll()
        cancelBehaviorFamilyLoads()
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
        guard let id = uniquePetID else { return false }
        return requestJump(request, for: id)
    }

    @discardableResult
    public func requestJump(_ request: JumpRequest, for id: PetID) -> Bool {
        guard overlay.runState.status.state == .running else { return false }
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
        guard let id = uniquePetID else { return false }
        return requestJump(to: target, for: id)
    }

    @discardableResult
    public func requestJump(to target: JumpRequest.Target, for id: PetID) -> Bool {
        guard let activity = world.pet(id)?.resumeActivity else { return false }
        return requestJump(JumpRequest(target: target, returnActivity: activity), for: id)
    }

    public func setActivity(_ activity: ResumeActivity) {
        guard let id = uniquePetID else { return }
        setActivity(activity, for: id)
    }

    public func setActivity(_ activity: ResumeActivity, for id: PetID) {
        guard overlay.runState.status.state == .running else { return }
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

    /// Displays a placeholder when no usable catalog entry exists. Real characters use `addCharacter`.
    public func show(_ character: LoadedCharacter) {
        guard character.isPlaceholder else {
            _ = addCharacter(character)
            return
        }
        guard character.isPlaceholder, world.pets.isEmpty else { return }
        let id = world.spawn(character.definition, scale: preferences.petSettings.scale)
        charactersByPetID[id] = character
        onCharacterIssuesChange?(id, character.issues)
        let placement = world.pet(id)?.attachment.map { "on \($0.surfaceID)" } ?? "waiting for a surface"
        Log.simulation.notice(
            "Pet \(id, privacy: .public) '\(character.definition.id.rawValue, privacy: .public)' spawned \(placement, privacy: .public)"
        )
        renderNow()
    }

    /// Adds a validated character without replacing or mutating any existing pet.
    @discardableResult
    public func addCharacter(_ candidate: LoadedCharacter) -> PetID? {
        guard isStarted, !candidate.isPlaceholder, !candidate.isDegraded,
            !world.pets.contains(where: { $0.characterID == candidate.definition.id })
        else { return nil }
        let id = world.spawn(candidate.definition, scale: preferences.petSettings.scale)
        guard world.pet(id)?.characterID == candidate.definition.id else { return nil }
        charactersByPetID[id] = candidate
        onCharacterIssuesChange?(id, candidate.issues)
        let placement = world.pet(id)?.attachment.map { "on \($0.surfaceID)" } ?? "waiting for a surface"
        Log.simulation.notice(
            "Pet \(id, privacy: .public) '\(candidate.definition.id.rawValue, privacy: .public)' spawned \(placement, privacy: .public)"
        )
        renderNow()
        return id
    }

    /// Removes one PetID and only its active pointer capture, lazy loads, events and render state.
    @discardableResult
    public func removeCharacter(_ id: PetID) -> Bool {
        guard world.pet(id) != nil else { return false }
        interactionController.cancel(.petUnavailable, for: id)
        cancelBehaviorFamilyLoads(for: id)
        charactersByPetID[id] = nil
        onCharacterIssuesChange?(id, [])
        let removed = world.removePet(id)
        events.removeAll { $0.petID == id }
        for snapshotID in screenSnapshots.keys {
            screenSnapshots[snapshotID]?.pets.removeAll { $0.id == id }
        }
        if removed { renderNow() }
        return removed
    }

    // MARK: - Overlay callbacks

    private func screensDidChange() {
        refreshWindowTracking()
        world.apply(.screens(overlay.screens))
        applySurfaces()
        for id in Array(renderers.keys) where !overlay.screens.contains(where: { $0.id == id }) {
            renderers[id]?.removeAll()
            renderers[id] = nil
            rendererViews[id] = nil
            screenSnapshots[id] = nil
        }
        for screen in overlay.screens {
            guard let view = overlay.contentView(for: screen.id), rendererViews[screen.id] !== view else { continue }
            renderers[screen.id]?.removeAll()
            renderers[screen.id] = PetRenderer(hostLayer: view.petLayerHost)
            rendererViews[screen.id] = view
            screenSnapshots[screen.id] = RenderSnapshot()
        }
        renderNow()
    }

    /// The Dock walkway as the world's surface set: a moved Dock keeps its surface (the pet rides it, clamped);
    /// a Dock hidden, shown or moved to a side replaces it (the pet re-settles below or above, T6.4).
    private func applySurfaces() {
        let floors = SurfaceMap.screenBottoms(for: overlay.screens)
        let walls = SurfaceMap.screenWalls(for: overlay.screens)
        var surfaces = overlay.dock.surfaces
        for surface in floors + walls + windowSurfacesForWorld
        where !surfaces.contains(where: { $0.id == surface.id }) {
            surfaces.append(surface)
        }
        world.apply(.surfaces(surfaces))
        #if DEBUG
            updateSurfaceDebugLine()
        #endif
    }

    private func statusDidChange(_ status: RunStatus) {
        if status.state != .running { world.apply(.suspendMusicBehaviors) }
        refreshMusicDetection()
        publishDanceAvailability()
        refreshWindowTracking()
        // Frames stopped: the next frame after they resume only records its timestamp (no catch-up).
        if !status.isFrameDriverRunning { accumulator.reset() }
    }

    /// Tracking runs only while explicitly enabled, Accessibility-trusted, and in the active run state.
    public func refreshWindowTracking() {
        guard preferences.isWindowInteractionEnabled, overlay.runState.status.state == .running,
            let converter = overlay.converter
        else {
            windowTracker.stop()
            return
        }
        if windowTracker.isAvailable {
            windowTracker.updateScreens(converter)
        } else {
            windowTracker.start(converter: converter)
        }
    }

    /// Reconciles a privacy-minimal tracker snapshot at the runtime boundary.
    func receiveTrackedWindows(_ windows: [TrackedWindow]) {
        let surfaces = WindowSurfaceBuilder.build(
            windows: windows, screens: overlay.screens)
        let now = ProcessInfo.processInfo.systemUptime
        if let previousTime = lastWindowSnapshotTime {
            let teleported = SurfaceMap.teleportedWindowIDs(
                from: lastTrackedWindows, to: windows, elapsed: now - previousTime)
            windowSurfacesForWorld = surfaces.filter {
                !SurfaceMap.belongsToWindow($0, identities: teleported)
            }
        } else {
            windowSurfacesForWorld = surfaces
        }
        lastWindowSnapshotTime = now
        lastTrackedWindows = windows
        trackedWindowSurfaces = surfaces
        #if DEBUG
            overlay.setWindowSurfaceDiagnostics(surfaces)
        #endif
        onTrackedWindowSurfacesChange?(surfaces)
        applySurfaces()
        renderNow()
    }

    /// Applies interaction facts through PetWorld and acknowledges them before native capture is latched.
    private func submitInteraction(_ id: PetID, command: InteractionCommand) -> Bool {
        guard world.pet(id) != nil else { return false }
        let isCancellation: Bool
        if case .cancel = command { isCancellation = true } else { isCancellation = false }
        if !isCancellation {
            guard overlay.runState.status.state == .running,
                preferences.petSettings.interaction.directInteractionEnabled
            else { return false }
        }
        world.apply(.interaction(id, command))
        events.removeAll(keepingCapacity: true)
        world.drainEvents(into: &events)
        let rejected = events.contains {
            if case .interactionRejected(let rejectedID, _) = $0 { return rejectedID == id }
            return false
        }
        let acceptedPress = events.contains {
            if case .interactionAccepted(let acceptedID, _) = $0 { return acceptedID == id }
            return false
        }
        if !events.isEmpty { log(events) }
        guard !rejected else { return false }
        if case .press = command, !acceptedPress { return false }
        renderNow()
        return true
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
        if let converter = overlay.converter {
            for screen in overlay.screens { screenSnapshots[screen.id]?.pets.removeAll(keepingCapacity: true) }
            for pet in snapshot.pets where pet.isVisible {
                guard let screen = screenForRendering(pet, among: overlay.screens) else { continue }
                screenSnapshots[screen.id]?.pets.append(pet)
            }
            for screen in overlay.screens {
                guard let screenSnapshot = screenSnapshots[screen.id] else { continue }
                renderers[screen.id]?.render(screenSnapshot, converter: converter, screen: screen) { pet in
                    guard let character = charactersByPetID[pet.id] else { return nil }
                    if let frame = character.frame(pet.frame) { return frame.image }
                    requestBehaviorFamilyLoad(pet.frame.clip, petID: pet.id, character: character)
                    return character.fallbackFrame(for: pet.frame)?.image
                }
            }
        }
        hitTester.update(snapshot) { pet in
            guard let character = charactersByPetID[pet.id] else { return nil }
            if let frame = character.frame(pet.frame) { return frame.hitMask }
            requestBehaviorFamilyLoad(pet.frame.clip, petID: pet.id, character: character)
            return character.fallbackFrame(for: pet.frame)?.hitMask
        }
        let demand = world.needsSimulationSteps || world.needsAnimationFrames
        overlay.preferredFramesPerSecond = world.pets.isEmpty ? 60 : world.preferredFramesPerSecond
        if !demand || demand != overlay.needsFrames { accumulator.reset() }
        overlay.needsFrames = demand
        refreshMusicDetection()
        publishDanceAvailability()
    }

    private func cancelBehaviorFamilyLoads(for petID: PetID) {
        guard let tasks = behaviorFamilyTasks.removeValue(forKey: petID) else { return }
        for task in tasks.values { task.cancel() }
    }

    private func cancelBehaviorFamilyLoads() {
        for tasks in behaviorFamilyTasks.values {
            for task in tasks.values { task.cancel() }
        }
        behaviorFamilyTasks.removeAll()
    }

    private func requestBehaviorFamilyLoad(_ clip: String, petID: PetID, character: LoadedCharacter) {
        let family = CharacterFrameCatalog.family(for: clip)
        guard !character.hasAttemptedBehaviorFamily(containing: clip), behaviorFamilyTasks[petID]?[family] == nil
        else {
            return
        }
        behaviorFamilyTasks[petID, default: [:]][family] = Task { [weak self, character] in
            let loaded = await character.loadBehaviorFamily(containing: clip)
            guard let self, self.isStarted, self.charactersByPetID[petID] === character,
                self.world.pet(petID) != nil
            else { return }
            self.behaviorFamilyTasks[petID]?[family] = nil
            if self.behaviorFamilyTasks[petID]?.isEmpty == true { self.behaviorFamilyTasks[petID] = nil }
            if !loaded { self.onCharacterIssuesChange?(petID, character.issues) }
            self.renderNow()
        }
    }

    /// Picks one screen for the sprite at a hand-off edge. Contact-point containment wins; while the
    /// contact point is between displays, keep the sprite on the screen with the largest visible overlap.
    private func screenForRendering(_ pet: PetRenderState, among screens: [ScreenDescriptor]) -> ScreenDescriptor? {
        var containing: ScreenDescriptor?
        for screen in screens
        where pet.position.x >= screen.frame.minX && pet.position.x < screen.frame.maxX
            && pet.position.y >= screen.frame.minY && pet.position.y < screen.frame.maxY
        {
            if let current = containing {
                if screen.id.rawValue < current.id.rawValue { containing = screen }
            } else {
                containing = screen
            }
        }
        if let containing { return containing }
        var best: ScreenDescriptor?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = pet.spriteRect.intersection(screen.frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea || (area == bestArea && area > 0 && screen.id.rawValue < (best?.id.rawValue ?? .max)) {
                best = screen
                bestArea = area
            }
        }
        return best
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
            case .interactionAccepted(let id, _):
                Log.simulation.debug("Pet \(id, privacy: .public) interaction accepted")
            case .interactionEnded(let id, _):
                Log.simulation.debug("Pet \(id, privacy: .public) interaction ended")
            case .interactionRejected(let id, _):
                Log.simulation.debug("Pet \(id, privacy: .public) interaction rejected")
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
