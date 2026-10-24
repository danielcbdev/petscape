/// Explicit intent origin; a music stop can interrupt automatic dancing without ending a manual dance.
public enum DanceSource: Equatable, Sendable {
    case automatic, manual

    /// Include both endpoints without changing the world's existing half-open activity draw.
    static func duration(using random: inout any RandomSource) -> Double {
        duration(unitRandom: Double(random.next() >> 11) / Double(UInt64.max >> 11))
    }

    static func duration(unitRandom: Double) -> Double { 5 + min(1, max(0, unitRandom)) * 25 }
}
