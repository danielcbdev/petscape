/// `PreferencesStore` that keeps values in memory only (tests, previews).
public final class InMemoryPreferencesStore: PreferencesStore {
    public var isPaused: Bool
    public var isHidden: Bool

    public init(isPaused: Bool = false, isHidden: Bool = false) {
        self.isPaused = isPaused
        self.isHidden = isHidden
    }
}
