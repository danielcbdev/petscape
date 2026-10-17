import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRendering

/// Runtime orchestration of the transparent overlay (M3): screens → overlays, system events and user
/// intent → run state → visibility / frame driver / idle cursor monitor, and cursor → pass-through.
/// `PetRuntime` (M5) adds the simulation on top of the same frame callback.
public final class OverlayCoordinator {
    public let runState: RunStateController
    public let passthrough: MousePassthroughController

    private let screenProvider: ScreenProvider
    private let cursorSampler: CursorSampler
    private let systemEvents: SystemEventsMonitor
    private let fullScreenDetector: FullScreenSpaceDetector
    private let overlays: OverlayWindowManager
    private let makeFrameDriver: (NSView) -> any FrameDriver
    private let hitTester = RectangleHitTester()

    private var converter: CoordinateConverter?
    private var hostScreenID: ScreenID?
    private var frameDriver: (any FrameDriver)?
    private var isStarted = false

    public init(
        screenProvider: ScreenProvider,
        cursorSampler: CursorSampler,
        systemEvents: SystemEventsMonitor,
        fullScreenDetector: FullScreenSpaceDetector,
        overlays: OverlayWindowManager = OverlayWindowManager(),
        runState: RunStateController,
        makeFrameDriver: @escaping (NSView) -> any FrameDriver = { DisplayLinkFrameDriver(view: $0) }
    ) {
        self.screenProvider = screenProvider
        self.cursorSampler = cursorSampler
        self.systemEvents = systemEvents
        self.fullScreenDetector = fullScreenDetector
        self.overlays = overlays
        self.runState = runState
        self.makeFrameDriver = makeFrameDriver
        var applyIgnores: (Bool) -> Void = { _ in }
        passthrough = MousePassthroughController(hitTester: hitTester) { applyIgnores($0) }
        applyIgnores = { [weak self] ignores in self?.applyIgnoresMouseEvents(ignores) }
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
        systemEvents.start { [weak self] reason, isActive in self?.runState.setCondition(reason, isActive: isActive) }
        fullScreenDetector.start { [weak self] isFullScreen in
            self?.runState.setCondition(.fullScreenSpace, isActive: isFullScreen)
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
        runState.onChange = nil
        overlays.onOcclusionChange = nil
        overlays.onMouseEvent = nil
        overlays.removeAll()
        Log.overlay.notice("Overlay stopped: observers, monitors and display link removed")
    }

    // MARK: Screens

    private func apply(screens: [ScreenDescriptor]) {
        converter = CoordinateConverter(screens: screens)
        // MVP: one overlay on the primary screen; T6.2/T6.6 host it on the Dock's screen instead.
        let host = converter?.primary
        runState.setCondition(.noScreens, isActive: host == nil)
        overlays.update(screens: screens, hosting: host.map { [$0.id] } ?? [])
        passthrough.reset()
        if host?.id != hostScreenID {
            hostScreenID = host?.id
            replaceFrameDriver()
        }
        #if DEBUG
            layOutDebugTarget(on: host)
        #endif
    }

    /// The display link belongs to the host overlay's view, so it follows that overlay.
    private func replaceFrameDriver() {
        frameDriver?.invalidate()
        frameDriver = nil
        guard let hostScreenID, let view = overlays.contentView(for: hostScreenID) else { return }
        let driver = makeFrameDriver(view)
        driver.onFrame = { [weak self] _ in self?.frame() }
        driver.isPaused = !runState.status.isFrameDriverRunning
        frameDriver = driver
    }

    // MARK: Run state

    private func apply(_ status: RunStatus) {
        overlays.setVisible(status.isOverlayVisible)
        frameDriver?.isPaused = !status.isFrameDriverRunning
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
    }

    // MARK: Per frame and mouse

    private func frame() {
        Signposts.measure(Signposts.Interval.frame) {
            passthrough.update(with: cursorSampler.sample())
        }
    }

    private func handle(_ event: OverlayMouseEvent) {
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

    /// DEBUG evidence for AC-21: clicks on the target never activate PetScape or make the overlay key.
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
        /// Size of the M3 test rectangle: the default pet canvas (FR-04, 96 pt).
        private static let debugTargetSize = CGSize(width: 96, height: 96)

        /// When on, a rectangle stands in for the pet: bottom-centered on the host screen, standing on the
        /// top edge of the Dock reservation (`visibleFrame.minY`), and is the pass-through target.
        public var showsDebugTarget = false {
            didSet {
                guard showsDebugTarget != oldValue else { return }
                layOutDebugTarget(on: hostScreenID.flatMap { converter?.screen(withID: $0) })
            }
        }

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

        private func layOutDebugTarget(on screen: ScreenDescriptor?) {
            guard let screen, let converter, showsDebugTarget else {
                hitTester.rect = nil
                if let id = screen?.id { overlays.contentView(for: id)?.setDebugTarget(nil) }
                passthrough.reset()
                return
            }
            let size = Self.debugTargetSize
            let rect = CGRect(
                x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY, width: size.width,
                height: size.height)
            hitTester.rect = rect
            let view = overlays.contentView(for: screen.id)
            view?.setDebugTarget(converter.overlayRect(fromGlobal: rect, on: screen))
            view?.showsBounds = showsOverlayBounds
            view?.showsPassthroughState = showsPassthroughState
            Log.overlay.notice(
                "Debug target at \(String(describing: rect), privacy: .public) on screen \(screen.id, privacy: .public)"
            )
        }
    #endif
}
