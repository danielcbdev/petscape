/// Hysteresis over classifier windows, independent of simulation frames and audio hardware.
public struct MusicSessionDetector: Sendable {
    public private(set) var isPlaying = false
    private var candidateElapsed = 0.0
    private var requiresSilence = false

    /// Platform preserves this latch across capture restarts only after an observed music session.
    public var isAwaitingSilence: Bool { requiresSilence }

    public init() {}

    /// `duration` is the new, nonoverlapping portion of a classifier result, in seconds.
    /// Returns only confirmed edges. Uncertain/invalid observations cannot complete an edge.
    public mutating func observe(confidence: Double, duration: Double) -> Bool? {
        guard confidence.isFinite, (0...1).contains(confidence), duration.isFinite,
            duration > 0, duration <= 1
        else {
            candidateElapsed = 0
            return nil
        }
        let candidate = (isPlaying || requiresSilence) ? confidence <= 0.35 : confidence >= 0.65
        guard candidate else {
            candidateElapsed = 0
            return nil
        }
        candidateElapsed += duration
        guard candidateElapsed + FixedStepAccumulator.tolerance >= 1 else { return nil }
        candidateElapsed = 0
        if requiresSilence {
            requiresSilence = false
            return nil
        }
        isPlaying.toggle()
        return isPlaying
    }

    /// A restarted capture must observe silence before it can consider ongoing playback a new session.
    public mutating func reset(requireSilence: Bool) {
        isPlaying = false
        candidateElapsed = 0
        requiresSilence = requireSilence
    }
}
