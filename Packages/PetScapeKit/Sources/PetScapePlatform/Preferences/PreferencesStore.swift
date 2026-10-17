import PetScapeCore

/// The user's persisted choices (FR-18, data-flow.md#persistence). MVP: pause and hide.
public protocol PreferencesStore: AnyObject {
    var isPaused: Bool { get set }
    var isHidden: Bool { get set }
}

extension PreferencesStore {
    /// Pause and hide as one value, to seed the run state at launch.
    public var userIntent: UserIntent {
        UserIntent(isPaused: isPaused, isHidden: isHidden)
    }
}
