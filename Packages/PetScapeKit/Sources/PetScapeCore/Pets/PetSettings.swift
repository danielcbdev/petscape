/// User-facing settings; defaults opt the production runtime into autonomy.
public struct PetSettings: Equatable, Sendable {
    public static let speedRange = 0.5...4.0
    public static let defaultSpeed = 2.0

    public var scale: Double { didSet { scale = Self.displayScale(scale) } }
    public var speed: Double { didSet { speed = Self.speedScale(speed) } }
    public var behavior: AutonomySettings
    public var interaction: InteractionSettings

    public init(
        scale: Double = 1, speed: Double = PetSettings.defaultSpeed, behavior: AutonomySettings = AutonomySettings(),
        interaction: InteractionSettings = InteractionSettings()
    ) {
        self.scale = Self.displayScale(scale)
        self.speed = Self.speedScale(speed)
        self.behavior = behavior
        self.interaction = interaction
    }

    static func displayScale(_ value: Double) -> Double { value.isFinite ? min(1.5, max(0.5, value)) : 1 }
    static func speedScale(_ value: Double) -> Double {
        value.isFinite ? min(speedRange.upperBound, max(speedRange.lowerBound, value)) : defaultSpeed
    }
}
