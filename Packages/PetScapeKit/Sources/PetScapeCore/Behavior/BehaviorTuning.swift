import CoreGraphics

/// Tunable behavior values, kept as data (state-machines.md: values adjusted after playtesting).
public struct BehaviorTuning: Equatable, Sendable {
    /// Clip every MVP state shows.
    public static let walkClip = "walk"

    /// How long a pet stands still at an edge before walking back (FR-09).
    public var turnHold: Double
    /// Walk speed and walk playback rate multiplier (feet stay in sync with the art, FR-07).
    public var speedScale: Double
    /// Ground speed in points/s at scale 1 when the walk clip declares no `nominalSpeed` (e.g. the placeholder).
    public var fallbackWalkSpeed: Double
    /// How far outside every screen frame a contact point may be before the pet is recovered.
    public var outOfBoundsMargin: CGFloat
    /// Optional base-weight overrides for tuning scenarios. Missing entries are unavailable; nil uses the
    /// personality/energy defaults. Eligibility, cooldowns and the low-energy safety guard still apply.
    public var activityWeights: [Activity: Double]?

    public init(
        turnHold: Double = 0.15, speedScale: Double = 1, fallbackWalkSpeed: Double = 20,
        outOfBoundsMargin: CGFloat = 8, activityWeights: [Activity: Double]? = nil
    ) {
        self.turnHold = turnHold
        self.speedScale = speedScale
        self.fallbackWalkSpeed = fallbackWalkSpeed
        self.outOfBoundsMargin = outOfBoundsMargin
        self.activityWeights = activityWeights
    }
}
