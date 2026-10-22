/// Bounded timing and gesture thresholds for direct pointer interaction.
public struct InteractionTuning: Equatable, Sendable {
    public var dragThreshold: Double
    public var clickReactionDuration: Double
    public var clickRepeatCooldown: Double
    public var pickupPresentationDuration: Double

    public init(
        dragThreshold: Double = 4,
        clickReactionDuration: Double = 0.6,
        clickRepeatCooldown: Double = 0.5,
        pickupPresentationDuration: Double = 0.2
    ) {
        self.dragThreshold = Self.positiveFinite(dragThreshold, fallback: 4)
        self.clickReactionDuration = Self.positiveFinite(clickReactionDuration, fallback: 0.6)
        self.clickRepeatCooldown = Self.positiveFinite(clickRepeatCooldown, fallback: 0.5)
        self.pickupPresentationDuration = Self.positiveFinite(pickupPresentationDuration, fallback: 0.2)
    }

    public static let `default` = InteractionTuning()

    private static func positiveFinite(_ value: Double, fallback: Double) -> Double {
        value.isFinite && value > 0 ? value : fallback
    }
}
