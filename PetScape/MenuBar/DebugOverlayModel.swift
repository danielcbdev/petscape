#if DEBUG
    import Observation
    import PetScapeRuntime

    /// DEBUG menu state for the overlay and the Dock walkway (debugging.md#debug-menu). Forwards to the runtime;
    /// no logic.
    @Observable
    final class DebugOverlayModel {
        @ObservationIgnored private let runtime: PetRuntime

        var showsOverlayBounds = false {
            didSet { runtime.overlay.showsOverlayBounds = showsOverlayBounds }
        }
        var showsPassthroughState = false {
            didSet { runtime.overlay.showsPassthroughState = showsPassthroughState }
        }
        var showsWalkway = false {
            didSet { runtime.showsWalkway = showsWalkway }
        }
        /// The persisted `dockOffsetAdjustment` in points (T6.3).
        private(set) var dockOffset: Double

        init(runtime: PetRuntime) {
            self.runtime = runtime
            dockOffset = runtime.dockOffsetAdjustment
        }

        func adjustDockOffset(by points: Double) {
            setDockOffset(dockOffset + points)
        }

        func setDockOffset(_ points: Double) {
            runtime.setDockOffsetAdjustment(points)
            dockOffset = runtime.dockOffsetAdjustment
        }
    }
#endif
