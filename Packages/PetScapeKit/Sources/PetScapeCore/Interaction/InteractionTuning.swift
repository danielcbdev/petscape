/// Bounded timing and gesture thresholds for direct pointer interaction.
public struct InteractionTuning: Equatable, Sendable {
    public var dragThreshold: Double
    /// One complete `curious` look and return (M15 V8 rework: 0.6 s cut the gesture mid-lift).
    public var clickReactionDuration: Double
    public var clickRepeatCooldown: Double
    public var pickupPresentationDuration: Double

    public init(
        dragThreshold: Double = 4,
        clickReactionDuration: Double = 1.8,
        clickRepeatCooldown: Double = 0.5,
        pickupPresentationDuration: Double = 0.2
    ) {
        self.dragThreshold = Self.positiveFinite(dragThreshold, fallback: 4)
        self.clickReactionDuration = Self.positiveFinite(clickReactionDuration, fallback: 1.8)
        self.clickRepeatCooldown = Self.positiveFinite(clickRepeatCooldown, fallback: 0.5)
        self.pickupPresentationDuration = Self.positiveFinite(pickupPresentationDuration, fallback: 0.2)
    }

    public static let `default` = InteractionTuning()

    private static func positiveFinite(_ value: Double, fallback: Double) -> Double {
        value.isFinite && value > 0 ? value : fallback
    }
}
