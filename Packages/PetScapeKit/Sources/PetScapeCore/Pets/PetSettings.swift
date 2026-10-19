/// User-facing settings; defaults opt the production runtime into autonomy.
public struct PetSettings: Equatable, Sendable {
    public var scale: Double { didSet { scale = Self.displayScale(scale) } }
    public var speed: Double { didSet { speed = Self.speedScale(speed) } }
    public var behavior: AutonomySettings

    public init(scale: Double = 1, speed: Double = 1, behavior: AutonomySettings = AutonomySettings()) {
        self.scale = Self.displayScale(scale)
        self.speed = Self.speedScale(speed)
        self.behavior = behavior
    }

    static func displayScale(_ value: Double) -> Double { value.isFinite ? min(1.5, max(0.5, value)) : 1 }
    static func speedScale(_ value: Double) -> Double { value.isFinite ? min(2, max(0.5, value)) : 1 }
}
