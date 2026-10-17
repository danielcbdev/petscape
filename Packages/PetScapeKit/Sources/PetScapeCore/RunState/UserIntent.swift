/// What the user asked for from the menu; persisted from M5 on (FR-18).
public struct UserIntent: Hashable, Sendable {
    public var isPaused: Bool
    public var isHidden: Bool

    public init(isPaused: Bool = false, isHidden: Bool = false) {
        self.isPaused = isPaused
        self.isHidden = isHidden
    }
}
