/// A single weighted draw at a decision boundary; never retries an unavailable request.
public enum ActivitySelector {
    public static func select(
        _ candidates: [ActivityCandidate], previous: Activity?, repetitions: Int,
        random: inout any RandomSource
    ) -> Activity {
        func valid(_ candidate: ActivityCandidate) -> Bool {
            candidate.weight.isFinite && candidate.weight > 0
        }
        let excludePrevious = repetitions >= 3 && candidates.contains { valid($0) && $0.activity != previous }
        func eligible(_ candidate: ActivityCandidate) -> Bool {
            valid(candidate) && (!excludePrevious || candidate.activity != previous)
        }
        // Normalize by the largest weight, so even finite weights near Double.max cannot overflow the sum.
        let maximum = candidates.filter(eligible).map(\.weight).max() ?? 0
        guard maximum > 0 else { return .idle }
        let total = candidates.reduce(0.0) { $0 + (eligible($1) ? $1.weight / maximum : 0) }
        var draw = Double(random.next() >> 11) * 0x1p-53 * total
        var last: Activity = .idle
        for candidate in candidates where eligible(candidate) {
            last = candidate.activity
            draw -= candidate.weight / maximum
            if draw < 0 { return candidate.activity }
        }
        return last
    }
}
