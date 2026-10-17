import PetScapeCore
import PetScapePlatform
import PetScapeRuntime

/// Composition root: creates and wires the long-lived objects (ADR-0002, conventions: no singletons).
/// Creating it has no side effects; windows, observers and monitors appear in `start()`.
final class AppContainer {
    private let overlay: OverlayCoordinator
    #if DEBUG
        let debugModel: DebugOverlayModel
    #endif

    init() {
        overlay = OverlayCoordinator(
            screenProvider: ScreenProvider(),
            cursorSampler: CursorSampler(),
            systemEvents: SystemEventsMonitor(),
            fullScreenDetector: FullScreenSpaceDetector(),
            runState: RunStateController())
        #if DEBUG
            debugModel = DebugOverlayModel(overlay: overlay)
        #endif
    }

    func start() {
        Log.app.notice("PetScape started")
        overlay.start()
        #if DEBUG
            debugModel.applyDefaults()
        #endif
    }

    /// Tears everything down before the process exits (FR-13: observers removed, windows closed).
    func stop() {
        overlay.stop()
        Log.app.notice("PetScape stopped")
    }
}
