/// A request from the behavior layer to show a clip by name (it never knows frame counts).
///
/// Priorities belong to the behavior layer (docs/specifications/state-machines.md), not to the assets.
public struct AnimationRequest: Equatable, Sendable {
    /// Requests at or above this priority interrupt even clips declared `interruptible: false`.
    public static let criticalPriority = 90

    public var clip: String
    public var priority: Int
    /// Start from frame 0 even when the requested clip is already playing.
    public var restart: Bool

    public init(clip: String, priority: Int = 0, restart: Bool = false) {
        self.clip = clip
        self.priority = priority
        self.restart = restart
    }
}
