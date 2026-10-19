#if DEBUG
    import Observation
    import PetScapeCore
    import PetScapeRuntime

    /// DEBUG menu state for the overlay and the Dock walkway (debugging.md#debug-menu). Forwards to the runtime;
    /// no logic.
    @Observable
    final class DebugOverlayModel {
        @ObservationIgnored private let runtime: PetRuntime
        private let settings: SettingsModel

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
        var dockOffset: Double { settings.dockOffsetAdjustment }

        init(runtime: PetRuntime, settings: SettingsModel) {
            self.runtime = runtime
            self.settings = settings
        }

        func jump(horizontalOffset: Double = 0) {
            runtime.requestJump(to: .horizontal(horizontalOffset))
        }

        func jumpToDock() {
            guard let x = runtime.currentSnapshot.pets.first?.position.x else { return }
            runtime.requestJump(to: .surface(.dock, x: x))
        }

        func setIdle(_ idle: Bool) {
            runtime.setActivity(idle ? .idle : .walking)
        }

        func adjustDockOffset(by points: Double) {
            settings.adjustDockOffset(by: points)
        }

        func setDockOffset(_ points: Double) {
            settings.setDockOffsetAdjustment(points)
        }
    }
#endif
