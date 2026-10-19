import Observation
import PetScapeRuntime

/// State the menu shows and the intents it forwards (views hold no logic; AGENTS.md §4).
/// Created by `AppDelegate`, filled and wired by `AppContainer`.
@Observable
final class AppModel {
    /// A short problem line shown at the top of the menu when the character failed to load or is degraded
    /// (FR-15); `nil` when everything loaded.
    var characterStatus: String?
    /// The user's pause and hide choices (FR-02 labels); persisted by the runtime (FR-18).
    var settings: SettingsModel?
    var isPaused: Bool { settings?.userIntent.isPaused ?? false }
    var isHidden: Bool { settings?.userIntent.isHidden ?? false }

    func togglePaused() { settings?.setPaused(!isPaused) }
    func toggleHidden() { settings?.setHidden(!isHidden) }

    #if DEBUG
        @ObservationIgnored var openAnimationPreviewAction: (() -> Void)?

        func openAnimationPreview() {
            openAnimationPreviewAction?()
        }
    #endif
}
