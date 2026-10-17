import Observation

/// State the menu shows and the intents it forwards (views hold no logic; AGENTS.md §4).
/// Created by `AppDelegate`, filled and wired by `AppContainer`.
@Observable
final class AppModel {
    /// A short problem line shown at the top of the menu when the character failed to load or is degraded
    /// (FR-15); `nil` when everything loaded.
    var characterStatus: String?

    #if DEBUG
        @ObservationIgnored var openAnimationPreviewAction: (() -> Void)?

        func openAnimationPreview() {
            openAnimationPreviewAction?()
        }
    #endif
}
