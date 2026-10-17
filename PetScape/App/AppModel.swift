import Observation

/// State the menu shows and the intents it forwards (views hold no logic; AGENTS.md §4).
/// Created by `AppDelegate`, filled and wired by `AppContainer`.
@Observable
final class AppModel {
    /// A short problem line shown at the top of the menu when the character failed to load or is degraded
    /// (FR-15); `nil` when everything loaded.
    var characterStatus: String?
    /// The user's pause and hide choices (FR-02 labels); persisted by the runtime (FR-18).
    private(set) var isPaused = false
    private(set) var isHidden = false

    @ObservationIgnored private var setPausedAction: ((Bool) -> Void)?
    @ObservationIgnored private var setHiddenAction: ((Bool) -> Void)?

    /// Connects the menu to the runtime, starting from the restored state.
    func bind(
        isPaused: Bool, isHidden: Bool, setPaused: @escaping (Bool) -> Void, setHidden: @escaping (Bool) -> Void
    ) {
        self.isPaused = isPaused
        self.isHidden = isHidden
        setPausedAction = setPaused
        setHiddenAction = setHidden
    }

    func togglePaused() {
        isPaused.toggle()
        setPausedAction?(isPaused)
    }

    func toggleHidden() {
        isHidden.toggle()
        setHiddenAction?(isHidden)
    }

    #if DEBUG
        @ObservationIgnored var openAnimationPreviewAction: (() -> Void)?

        func openAnimationPreview() {
            openAnimationPreviewAction?()
        }
    #endif
}
