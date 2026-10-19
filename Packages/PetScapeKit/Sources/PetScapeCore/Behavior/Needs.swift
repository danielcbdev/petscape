/// Dynamic needs evolve exclusively with simulated time, never wall time.
public struct Needs: Equatable, Sendable {
    public private(set) var energy: Double

    public init(energy: Double = 0.7) {
        self.energy = energy.isFinite ? min(1, max(0, energy)) : 0.7
    }

    public mutating func advance(by dt: Double, sleeping: Bool) {
        guard dt.isFinite, dt > 0 else { return }
        energy = min(1, max(0, energy + dt * (sleeping ? 1 / 45 : -1 / 300)))
    }
}
