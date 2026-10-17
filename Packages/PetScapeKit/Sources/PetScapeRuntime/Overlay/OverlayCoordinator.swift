import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRendering

/// Runtime orchestration of the transparent overlay (M3): screens → Dock estimate → overlays, system events and
/// user intent → run state → visibility / frame driver / idle cursor monitor, and cursor → pass-through.
/// `PetRuntime` (M5) adds the simulation through the hooks below; each frame runs `onFrame` (simulate,
/// render) before the pass-through update, so the cursor is tested against the pet as just drawn.
public final class OverlayCoordinator {
    public let runState: RunStateController
    public let passthrough: MousePassthroughController
    /// The Dock estimate and walkway, updated with every screen change (M6); it decides the host screen.
    public let dock: DockSurfaceProvider

    /// Called on every display frame while frames run, before the pass-through update.
    public var onFrame: ((_ timestamp: TimeInterval) -> Void)?
    /// Called after the screens, the host overlay or its frame driver changed (also once from `start()`).
    public var onScreensChange: (() -> Void)?
    /// Called after every run status change has been applied.
    public var onStatusChange: ((RunStatus) -> Void)?
    /// Mouse events the overlay received (only while pass-through is off, i.e. over a pet).
    public var onMouseEvent: ((OverlayMouseEvent) -> Void)?

    /// `false` stops the frame driver even while running, when nothing on screen changes (no pet placed).
    public var needsFrames = true {
        didSet { if needsFrames != oldValue { updateFrameDriver() } }
    }

    /// Frame rate asked from the display link (T5.7): 60 caps ProMotion displays at the simulation rate.
    public var preferredFramesPerSecond: Float = 60 {
        didSet { frameDriver?.preferredFramesPerSecond = preferredFramesPerSecond }
    }

    /// Converter for the current screens; `nil` without screens.
    public private(set) var converter: CoordinateConverter?

    private let screenProvider: ScreenProvider
    private let cursorSampler: CursorSampler
    private let systemEvents: SystemEventsMonitor
    private let fullScreenDetector: FullScreenSpaceDetector
    private let overlays: OverlayWindowManager
    private let makeFrameDriver: (NSView) -> any FrameDriver

    private var hostScreenID: ScreenID?
    /// The screens last applied, to skip re-reads that change nothing.
    private var screens: [ScreenDescriptor] = []
    private var frameDriver: (any FrameDriver)?
    private var isStarted = false

    public init(
        screenProvider: ScreenProvider,
        cursorSampler: CursorSampler,
        systemEvents: SystemEventsMonitor,
        fullScreenDetector: FullScreenSpaceDetector,
        overlays: OverlayWindowManager = OverlayWindowManager(),
        runState: RunStateController,
        dock: DockSurfaceProvider = DockSurfaceProvider(),
        hitTester: any PetHitTesting,
        makeFrameDriver: @escaping (NSView) -> any FrameDriver = { DisplayLinkFrameDriver(view: $0) }
    ) {
        self.screenProvider = screenProvider
        self.cursorSampler = cursorSampler
        self.systemEvents = systemEvents
        self.fullScreenDetector = fullScreenDetector
        self.overlays = overlays
        self.runState = runState
        self.dock = dock
        self.makeFrameDriver = makeFrameDriver
        var applyIgnores: (Bool) -> Void = { _ in }
        passthrough = MousePassthroughController(hitTester: hitTester) { applyIgnores($0) }
        applyIgnores = { [weak self] ignores in self?.applyIgnoresMouseEvents(ignores) }
    }

    /// The screen hosting the overlay with the pets: the Dock's screen, or the primary screen while the Dock is
    /// hidden or unknown (T6.2, T6.6).
    public var hostScreen: ScreenDescriptor? {
        hostScreenID.flatMap { converter?.screen(withID: $0) }
    }

    /// The host overlay's content view (pet layers go into its `petLayerHost`).
    public var hostContentView: OverlayContentView? {
        hostScreenID.flatMap { overlays.contentView(for: $0) }
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        runState.onChange = { [weak self] status in self?.apply(status) }
        overlays.onOcclusionChange = { [weak self] visible in
            self?.runState.setCondition(.overlayOccluded, isActive: !visible)
        }
        overlays.onMouseEvent = { [weak self] _, event in self?.handle(event) }
        apply(screens: screenProvider.currentScreens())
        screenProvider.start { [weak self] screens in self?.apply(screens: screens) }
        systemEvents.start { [weak self] reason, isActive in self?.setCondition(reason, isActive: isActive) }
        fullScreenDetector.start { [weak self] isFullScreen in
            self?.setCondition(.fullScreenSpace, isActive: isFullScreen)
        }
        apply(runState.status)
    }

    /// Removes every observer and monitor, stops the display link and closes the overlays (FR-13).
    public func stop() {
        guard isStarted else { return }
        isStarted = false
        fullScreenDetector.stop()
        systemEvents.stop()
        screenProvider.stop()
        cursorSampler.stopMonitoring()
        frameDriver?.invalidate()
        frameDriver = nil
        onFrame = nil
        onScreensChange = nil
        onStatusChange = nil
        onMouseEvent = nil
        runState.onChange = nil
        overlays.onOcclusionChange = nil
        overlays.onMouseEvent = nil
        overlays.removeAll()
        Log.overlay.notice("Overlay stopped: observers, monitors and display link removed")
    }

    // MARK: Screens

    private func apply(screens: [ScreenDescriptor]) {
        self.screens = screens
        converter = CoordinateConverter(screens: screens)
        dock.update(screens: screens)
        // One overlay, on the Dock's screen (the walkway's screen); the others are closed (performance.md).
        let host = dock.hostScreenID.flatMap { converter?.screen(withID: $0) } ?? converter?.primary
        runState.setCondition(.noScreens, isActive: host == nil)
        overlays.update(screens: screens, hosting: host.map { [$0.id] } ?? [])
        passthrough.reset()
        if host?.id != hostScreenID {
            Log.overlay.notice("Host screen: \(host.map { String(describing: $0.id) } ?? "none", privacy: .public)")
            hostScreenID = host?.id
            replaceFrameDriver()
        }
        #if DEBUG
            for id in overlays.screenIDs {
                overlays.contentView(for: id)?.showsBounds = showsOverlayBounds
                overlays.contentView(for: id)?.showsPassthroughState = showsPassthroughState
            }
        #endif
        onScreensChange?()
    }

    /// The display link belongs to the host overlay's view, so it follows that overlay.
    private func replaceFrameDriver() {
        frameDriver?.invalidate()
        frameDriver = nil
        guard let hostScreenID, let view = overlays.contentView(for: hostScreenID) else { return }
        let driver = makeFrameDriver(view)
        driver.onFrame = { [weak self] timestamp in self?.frame(timestamp) }
        driver.preferredFramesPerSecond = preferredFramesPerSecond
        frameDriver = driver
        updateFrameDriver()
    }

    /// Frames run only while running and while something on screen changes (`needsFrames`).
    private func updateFrameDriver() {
        frameDriver?.isPaused = !(runState.status.isFrameDriverRunning && needsFrames)
    }

    /// The fallback re-read of ADR-0009 / PoC E3, without polling: screen changes made while asleep, locked,
    /// switched out or in a full-screen Space may not arrive as a notification afterwards, so the screens are
    /// read again whenever such a condition ends, and applied only if they differ.
    private func refreshScreensIfChanged() {
        let current = screenProvider.currentScreens()
        guard current != screens else { return }
        Log.overlay.notice("Screens changed while suspended: \(ScreenProvider.summary(of: current), privacy: .public)")
        apply(screens: current)
    }

    // MARK: Run state

    private func setCondition(_ reason: SuspensionReason, isActive: Bool) {
        runState.setCondition(reason, isActive: isActive)
        if !isActive && reason != .overlayOccluded { refreshScreensIfChanged() }
    }

    private func apply(_ status: RunStatus) {
        overlays.setVisible(status.isOverlayVisible)
        updateFrameDriver()
        if status.isIdleCursorMonitorNeeded {
            cursorSampler.startMonitoring { [weak self] sample in self?.passthrough.update(with: sample) }
        } else {
            cursorSampler.stopMonitoring()
        }
        if !status.isOverlayVisible {
            passthrough.reset()
        } else if !status.isFrameDriverRunning {
            // No frames: take one sample now so the state is right before the first mouse move.
            passthrough.update(with: cursorSampler.sample())
        }
        onStatusChange?(status)
    }

    // MARK: Per frame and mouse

    private func frame(_ timestamp: TimeInterval) {
        Signposts.measure(Signposts.Interval.frame) {
            onFrame?(timestamp)
            passthrough.update(with: cursorSampler.sample())
        }
    }

    private func handle(_ event: OverlayMouseEvent) {
        onMouseEvent?(event)
        switch event.kind {
        case .moved:
            passthrough.update(
                with: CursorSample(location: event.location, isButtonDown: false, timestamp: event.timestamp))
        case .down:
            logReceived(event)
            passthrough.mouseDown(at: event.location)
        case .dragged:
            break  // Dragging the pet arrives in M10.
        case .up:
            logReceived(event)
            passthrough.mouseUp(at: event.location)
        }
    }

    private func applyIgnoresMouseEvents(_ ignores: Bool) {
        overlays.setIgnoresMouseEvents(ignores)
        #if DEBUG
            for id in overlays.screenIDs { overlays.contentView(for: id)?.setInteractive(!ignores) }
        #endif
    }

    /// DEBUG evidence for AC-21: clicks on the pet never activate PetScape or make the overlay key.
    private func logReceived(_ event: OverlayMouseEvent) {
        #if DEBUG
            let isKey = hostScreenID.flatMap { overlays.panel(for: $0)?.isKeyWindow } ?? false
            Log.overlay.debug(
                "Overlay received \(String(describing: event.kind), privacy: .public) at (\(event.location.x, format: .fixed(precision: 1), privacy: .public), \(event.location.y, format: .fixed(precision: 1), privacy: .public)); app active=\(NSApp.isActive, privacy: .public) overlay key=\(isKey, privacy: .public)"
            )
        #endif
    }

    // MARK: DEBUG

    #if DEBUG
        public var showsOverlayBounds = false {
            didSet { for id in overlays.screenIDs { overlays.contentView(for: id)?.showsBounds = showsOverlayBounds } }
        }

        public var showsPassthroughState = false {
            didSet {
                for id in overlays.screenIDs {
                    overlays.contentView(for: id)?.showsPassthroughState = showsPassthroughState
                }
            }
        }
    #endif
}
