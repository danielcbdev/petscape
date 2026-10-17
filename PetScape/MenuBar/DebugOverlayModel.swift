#if DEBUG
    import Observation
    import PetScapeRuntime

    /// DEBUG menu state for the overlay (debugging.md#debug-menu). Forwards to the runtime; no logic.
    @Observable
    final class DebugOverlayModel {
        @ObservationIgnored private let overlay: OverlayCoordinator

        /// The M3 test rectangle standing in for the pet; on by default in DEBUG builds.
        var showsTarget = true {
            didSet { overlay.showsDebugTarget = showsTarget }
        }
        var showsOverlayBounds = false {
            didSet { overlay.showsOverlayBounds = showsOverlayBounds }
        }
        var showsPassthroughState = false {
            didSet { overlay.showsPassthroughState = showsPassthroughState }
        }
        /// Stand-ins for the M5 Pause/Hide items, to exercise the run state and the idle cursor monitor.
        var isPaused = false {
            didSet { overlay.runState.setPaused(isPaused) }
        }
        var isHidden = false {
            didSet { overlay.runState.setHidden(isHidden) }
        }

        init(overlay: OverlayCoordinator) {
            self.overlay = overlay
        }

        /// Pushes the initial values once the overlay is running.
        func applyDefaults() {
            overlay.showsDebugTarget = showsTarget
            overlay.showsOverlayBounds = showsOverlayBounds
            overlay.showsPassthroughState = showsPassthroughState
        }
    }
#endif
