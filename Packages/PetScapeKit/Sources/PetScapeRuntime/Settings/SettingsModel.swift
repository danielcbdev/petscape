import Observation
import PetScapeCore
import PetScapePlatform

/// Native Settings presentation and intents. Domain mutations stay in PetRuntime/PetWorld.
@Observable
public final class SettingsModel {
    public private(set) var petSettings: PetSettings
    public private(set) var userIntent: UserIntent
    public private(set) var dockOffsetAdjustment: Double
    public private(set) var loginStatus: LaunchAtLoginStatus
    public private(set) var loginError: LaunchAtLoginError?

    @ObservationIgnored private let runtime: PetRuntime
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let loginService: any LaunchAtLoginService

    public init(runtime: PetRuntime, preferences: any PreferencesStore, loginService: any LaunchAtLoginService) {
        self.runtime = runtime
        self.preferences = preferences
        self.loginService = loginService
        petSettings = runtime.petSettings
        userIntent = runtime.userIntent
        dockOffsetAdjustment = runtime.dockOffsetAdjustment
        loginStatus = loginService.status
        runtime.onUserIntentChange = { [weak self] intent in self?.userIntent = intent }
    }

    public var isLaunchAtLoginEnabled: Bool {
        loginStatus == .enabled || loginStatus == .requiresApproval
    }

    public func refreshLoginStatus() { loginStatus = loginService.status }

    public func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        refreshLoginStatus()
        guard enabled != isLaunchAtLoginEnabled else { return }
        do { try loginService.setEnabled(enabled) } catch { loginError = error }
        refreshLoginStatus()
    }

    public func setScale(_ scale: Double) { update { $0.scale = scale } }
    public func setSpeed(_ speed: Double) { update { $0.speed = speed } }
    public func setAutonomyEnabled(_ enabled: Bool) { update { $0.behavior.isEnabled = enabled } }
    public func setJumpsEnabled(_ enabled: Bool) { update { $0.behavior.jumpsEnabled = enabled } }
    public func setRestEnabled(_ enabled: Bool) { update { $0.behavior.restEnabled = enabled } }
    public func setExpressionsEnabled(_ enabled: Bool) { update { $0.behavior.expressionsEnabled = enabled } }
    public func setCursorReactionsEnabled(_ enabled: Bool) {
        update { $0.interaction.cursorReactionsEnabled = enabled }
    }
    public func setDirectInteractionEnabled(_ enabled: Bool) {
        update { $0.interaction.directInteractionEnabled = enabled }
    }
    public func setPaused(_ paused: Bool) { runtime.setPaused(paused) }
    public func setHidden(_ hidden: Bool) { runtime.setHidden(hidden) }
    public func wakePet() { runtime.wakePet() }

    public func setDockOffsetAdjustment(_ offset: Double) {
        runtime.setDockOffsetAdjustment(offset)
        dockOffsetAdjustment = runtime.dockOffsetAdjustment
    }

    public func adjustDockOffset(by points: Double) {
        setDockOffsetAdjustment(runtime.dockOffsetAdjustment + points)
    }

    /// An explicit user action, including unregistering an enabled or pending login item.
    public func restoreDefaults() {
        preferences.restoreDefaults()
        runtime.setPetSettings(preferences.petSettings)
        petSettings = runtime.petSettings
        setDockOffsetAdjustment(preferences.dockOffsetAdjustment)
        setPaused(preferences.isPaused)
        setHidden(preferences.isHidden)
        setLaunchAtLogin(false)
    }

    private func update(_ change: (inout PetSettings) -> Void) {
        var settings = petSettings
        change(&settings)
        runtime.setPetSettings(settings)
        petSettings = runtime.petSettings
    }
}
