/// Turns display-frame timestamps into a number of fixed simulation steps (ADR-0013).
///
/// - Real frame deltas are clamped to `maxFrameDelta` (a stall never fast-forwards the world).
/// - At most `maxStepsPerFrame` steps run per frame; a larger backlog is dropped, not carried over.
/// - The first frame after `init`/`reset()` only records its timestamp, so resuming after a pause, sleep or
///   hide never catches up on the wall time that passed.
public struct FixedStepAccumulator: Equatable, Sendable {
    public static let defaultStep = 1.0 / 60
    /// Tolerance so frames that are exactly one step long (60 Hz) are not lost to rounding.
    static let tolerance = 1e-9

    public let step: Double
    public let maxStepsPerFrame: Int
    public let maxFrameDelta: Double
    /// Unsimulated time, in `0..<step` after every frame.
    public private(set) var accumulated: Double = 0
    public private(set) var lastTimestamp: Double?

    public init(step: Double = defaultStep, maxStepsPerFrame: Int = 5, maxFrameDelta: Double = 0.25) {
        precondition(step > 0 && maxStepsPerFrame > 0 && maxFrameDelta > 0, "Invalid accumulator configuration")
        self.step = step
        self.maxStepsPerFrame = maxStepsPerFrame
        self.maxFrameDelta = maxFrameDelta
    }

    /// Fraction of a step not yet simulated (render interpolation α, unused until judder is measured).
    public var interpolation: Double { accumulated / step }

    /// The number of steps of `step` seconds to run for the frame at `timestamp` (seconds, monotonic).
    public mutating func steps(forFrameAt timestamp: Double) -> Int {
        guard timestamp.isFinite else { return 0 }
        defer { lastTimestamp = timestamp }
        guard let lastTimestamp else { return 0 }
        let delta = timestamp - lastTimestamp
        guard delta.isFinite, delta > 0 else { return 0 }
        accumulated += min(delta, maxFrameDelta)
        let available = Int((accumulated + Self.tolerance) / step)
        let steps = min(available, maxStepsPerFrame)
        accumulated = max(0, accumulated - Double(steps) * step)
        if available > maxStepsPerFrame {
            accumulated = accumulated.truncatingRemainder(dividingBy: step)
        }
        return steps
    }

    /// Forgets the last timestamp and any unsimulated time (call when frames stop).
    public mutating func reset() {
        accumulated = 0
        lastTimestamp = nil
    }
}
