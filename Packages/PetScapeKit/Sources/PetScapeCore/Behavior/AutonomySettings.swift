/// Live behavior policy. Explicit jump commands retain their independent M8 guards.
public struct AutonomySettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var jumpsEnabled: Bool
    public var restEnabled: Bool
    public var expressionsEnabled: Bool

    public init(
        isEnabled: Bool = true, jumpsEnabled: Bool = true, restEnabled: Bool = true, expressionsEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.jumpsEnabled = jumpsEnabled
        self.restEnabled = restEnabled
        self.expressionsEnabled = expressionsEnabled
    }
}
