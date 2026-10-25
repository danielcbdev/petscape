#if DEBUG
    import Observation
    import PetScapeCore
    import PetScapeRuntime

    enum WindowSurfaceDiagnostic: Equatable {
        case interactionDisabled
        case permissionMissing
        case noSegments
        case segmentCount(Int)
    }

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
        var showsWindowSurfaces = false {
            didSet {
                if showsWindowSurfaces { settings.refreshWindowPermissionStatus() }
                runtime.overlay.showsWindowSurfaces = showsWindowSurfaces
            }
        }
        private(set) var windowSurfaceCount = 0

        var windowSurfaceStatus: WindowSurfaceDiagnostic {
            guard settings.isWindowInteractionEnabled else {
                return .interactionDisabled
            }
            guard !settings.isWindowPermissionMissing else {
                return .permissionMissing
            }
            guard windowSurfaceCount > 0 else {
                return .noSegments
            }
            return .segmentCount(windowSurfaceCount)
        }
        /// The persisted `dockOffsetAdjustment` in points (T6.3).
        var dockOffset: Double { settings.dockOffsetAdjustment }
        var hasUnambiguousPetTarget: Bool { runtime.pets.count == 1 }

        init(runtime: PetRuntime, settings: SettingsModel) {
            self.runtime = runtime
            self.settings = settings
            runtime.onTrackedWindowSurfacesChange = { [weak self] surfaces in
                self?.windowSurfaceCount = surfaces.count
            }
        }

        func jump(horizontalOffset: Double = 0) {
            guard runtime.pets.count == 1 else { return }
            runtime.requestJump(to: .horizontal(horizontalOffset), for: runtime.pets[0].id)
        }

        func jumpToDock() {
            guard runtime.pets.count == 1, let pet = runtime.currentSnapshot.pets.first else { return }
            runtime.requestJump(to: .surface(.dock, x: pet.position.x), for: pet.id)
        }

        func setIdle(_ idle: Bool) {
            guard runtime.pets.count == 1 else { return }
            runtime.setActivity(idle ? .idle : .walking, for: runtime.pets[0].id)
        }

        func adjustDockOffset(by points: Double) {
            settings.adjustDockOffset(by: points)
        }

        func setDockOffset(_ points: Double) {
            settings.setDockOffsetAdjustment(points)
        }
    }
#endif
