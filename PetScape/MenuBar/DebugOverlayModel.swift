#if DEBUG
    import Observation
    import PetScapeRuntime

    /// DEBUG menu state for the overlay (debugging.md#debug-menu). Forwards to the runtime; no logic.
    @Observable
    final class DebugOverlayModel {
        @ObservationIgnored private let overlay: OverlayCoordinator

        var showsOverlayBounds = false {
            didSet { overlay.showsOverlayBounds = showsOverlayBounds }
        }
        var showsPassthroughState = false {
            didSet { overlay.showsPassthroughState = showsPassthroughState }
        }

        init(overlay: OverlayCoordinator) {
            self.overlay = overlay
        }
    }
#endif
