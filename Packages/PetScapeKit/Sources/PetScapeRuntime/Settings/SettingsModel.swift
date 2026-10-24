import Observation
import PetScapeCore
import PetScapePlatform

/// Native Settings presentation and intents. Domain mutations stay in PetRuntime/PetWorld.
@Observable
public final class SettingsModel {
    public let characterSelection: CharacterSelectionModel?
    public private(set) var petSettings: PetSettings
    public private(set) var userIntent: UserIntent
    public private(set) var dockOffsetAdjustment: Double
    public private(set) var loginStatus: LaunchAtLoginStatus
    public private(set) var loginError: LaunchAtLoginError?
    public var isWindowInteractionEnabled: Bool { preferences.isWindowInteractionEnabled }
    public private(set) var isWindowPermissionMissing = false
    public var isWindowPermissionConfirmationPresented = false
    public private(set) var isMusicDancingEnabled: Bool
    public private(set) var musicStatus: MusicDetectionStatus
    public private(set) var canDance: Bool
    public private(set) var canStopDance: Bool
    public var isMusicConsentPresented = false
    public var isSpecialArtworkPending: Bool { runtime.isSpecialArtworkPending }

    @ObservationIgnored private let runtime: PetRuntime
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let loginService: any LaunchAtLoginService
    @ObservationIgnored private let accessibilityPermission: any AccessibilityPermissionProviding

    public init(
        runtime: PetRuntime, preferences: any PreferencesStore, loginService: any LaunchAtLoginService,
        accessibilityPermission: any AccessibilityPermissionProviding = AccessibilityPermission(),
        characterSelection: CharacterSelectionModel? = nil
    ) {
        self.characterSelection = characterSelection
        self.runtime = runtime
        self.preferences = preferences
        self.loginService = loginService
        self.accessibilityPermission = accessibilityPermission
        petSettings = runtime.petSettings
        userIntent = runtime.userIntent
        dockOffsetAdjustment = runtime.dockOffsetAdjustment
        loginStatus = loginService.status
        isMusicDancingEnabled = preferences.isMusicDancingEnabled
        musicStatus = runtime.musicStatus
        canDance = runtime.canDance
        canStopDance = runtime.canStopDance
        runtime.onMusicStatusChange = { [weak self] status in self?.musicStatus = status }
        runtime.onStopDanceAvailabilityChange = { [weak self] available in self?.canStopDance = available }
        runtime.onDanceAvailabilityChange = { [weak self] available in self?.canDance = available }
        runtime.onUserIntentChange = { [weak self] intent in self?.userIntent = intent }
    }

    public var isLaunchAtLoginEnabled: Bool {
        loginStatus == .enabled || loginStatus == .requiresApproval
    }

    public func refreshLoginStatus() { loginStatus = loginService.status }

    /// Permission checks are intentionally skipped until the opt-in preference is enabled.
    public func refreshWindowPermissionStatus() {
        guard preferences.isWindowInteractionEnabled else {
            isWindowPermissionMissing = false
            runtime.refreshWindowTracking()
            return
        }
        isWindowPermissionMissing = !accessibilityPermission.isTrusted
        runtime.refreshWindowTracking()
    }

    public func setWindowInteractionEnabled(_ enabled: Bool) {
        preferences.isWindowInteractionEnabled = enabled
        guard enabled else {
            isWindowPermissionMissing = false
            isWindowPermissionConfirmationPresented = false
            runtime.refreshWindowTracking()
            return
        }
        refreshWindowPermissionStatus()
        if isWindowPermissionMissing { isWindowPermissionConfirmationPresented = true }
        runtime.refreshWindowTracking()
    }

    public func confirmWindowPermissionRequest() {
        guard preferences.isWindowInteractionEnabled, isWindowPermissionMissing else { return }
        isWindowPermissionConfirmationPresented = false
        accessibilityPermission.requestAuthorizationPrompt()
        _ = accessibilityPermission.openSettings()
    }

    public func cancelWindowPermissionRequest() {
        preferences.isWindowInteractionEnabled = false
        isWindowPermissionMissing = false
        isWindowPermissionConfirmationPresented = false
        runtime.refreshWindowTracking()
    }

    public func windowPermissionWasRevoked() {
        isWindowPermissionMissing = preferences.isWindowInteractionEnabled
    }

    public func setMusicDancingEnabled(_ enabled: Bool) {
        if enabled {
            isMusicConsentPresented = true
        } else {
            isMusicConsentPresented = false
            isMusicDancingEnabled = false
            runtime.setMusicDancingEnabled(false)
        }
    }

    public func confirmMusicConsent() {
        isMusicConsentPresented = false
        isMusicDancingEnabled = true
        runtime.setMusicDancingEnabled(true)
    }

    public func cancelMusicConsent() { isMusicConsentPresented = false }
    public func dance() { runtime.requestDance() }
    public func stopDance() { runtime.stopDance() }

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
        isWindowPermissionMissing = false
        setMusicDancingEnabled(false)
        runtime.refreshWindowTracking()
        setLaunchAtLogin(false)
    }

    private func update(_ change: (inout PetSettings) -> Void) {
        var settings = petSettings
        change(&settings)
        runtime.setPetSettings(settings)
        petSettings = runtime.petSettings
    }
}
