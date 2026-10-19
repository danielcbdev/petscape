public struct ActivityCandidate: Equatable, Sendable {
    public let activity: Activity
    public let weight: Double

    public init(_ activity: Activity, weight: Double) {
        self.activity = activity
        self.weight = weight
    }
}
