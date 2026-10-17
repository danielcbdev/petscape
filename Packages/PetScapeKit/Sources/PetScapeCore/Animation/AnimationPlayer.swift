/// Plays one clip from simulation time (docs/architecture/animation-system.md#playback-model).
///
/// A value type with no clock: it advances only when `advance(by:into:)` is called, so pausing the
/// simulation pauses the animation and tests are deterministic. A single step may cross several frames
/// (long step, short frames); every crossed event is emitted, in order.
public struct AnimationPlayer: Equatable, Sendable {
    /// Tolerance when comparing elapsed time with a frame boundary, so boundaries that fall exactly on a
    /// step (e.g. 9 fps stepped at 60 Hz every 20 steps) are not missed by floating-point rounding.
    static let boundaryTolerance = 1e-9
    /// Repeating clips play at most this many whole cycles per step; further cycles are skipped (see
    /// `skippingWholeCycles`). A 60 Hz simulation never gets near it; it bounds the work after a stall.
    static let maxCyclesPerStep = 16.0

    public private(set) var clip: AnimationClip
    public private(set) var frameIndex: Int = 0
    /// `true` once a `once` clip has played its last frame to the end (it then holds that frame).
    public private(set) var isFinished = false
    /// Time left over from the step in which a `once` clip finished, at rate 1 (used by `next` chaining).
    public private(set) var unusedTime: Double = 0
    /// Playback speed multiplier; 0 freezes the clip. Negative values are treated as 0.
    public var rate: Double {
        didSet { rate = rate.isFinite ? max(0, rate) : 0 }
    }

    private var timeInFrame: Double = 0
    private var pingPongForward = true
    private var hasEnteredCurrentFrame = false

    public init(clip: AnimationClip, rate: Double = 1) {
        self.clip = clip
        self.rate = rate.isFinite ? max(0, rate) : 0
    }

    /// Starts the clip again from frame 0 (its entry events are emitted by the next `advance`).
    public mutating func restart() {
        frameIndex = 0
        isFinished = false
        unusedTime = 0
        timeInFrame = 0
        pingPongForward = true
        hasEnteredCurrentFrame = false
    }

    /// Shows `index` from its start without emitting its events (e.g. switching to a direction variant).
    public mutating func jump(toFrame index: Int) {
        restart()
        frameIndex = min(max(0, index), clip.frames.count - 1)
        hasEnteredCurrentFrame = true
    }

    /// Advances by `dt` seconds of simulation time, appending events to `events` (not cleared first, so a
    /// caller can reuse one buffer without allocating per frame).
    ///
    /// The first call after `init`/`restart` emits the entry events of frame 0, even for `dt == 0`.
    public mutating func advance(by dt: Double, into events: inout [AnimationEvent]) {
        if !hasEnteredCurrentFrame {
            hasEnteredCurrentFrame = true
            enter(frameIndex, into: &events)
        }
        guard !isFinished, dt.isFinite, dt > 0, rate > 0 else { return }

        timeInFrame += skippingWholeCycles(dt * rate)
        while timeInFrame + Self.boundaryTolerance >= clip.frames[frameIndex].duration {
            timeInFrame = max(0, timeInFrame - clip.frames[frameIndex].duration)
            if !stepToNextFrame(into: &events) { return }
        }
    }

    /// Convenience for tests and non-hot paths.
    public mutating func advance(by dt: Double) -> [AnimationEvent] {
        var events: [AnimationEvent] = []
        advance(by: dt, into: &events)
        return events
    }

    // MARK: - Private

    /// Moves to the following frame; returns `false` when a `once` clip finished.
    private mutating func stepToNextFrame(into events: inout [AnimationEvent]) -> Bool {
        let lastIndex = clip.frames.count - 1
        switch clip.playback {
        case .loop:
            if frameIndex == lastIndex {
                frameIndex = 0
                events.append(AnimationEvent(clip: clip.name, frameIndex: 0, kind: .loopCompleted))
            } else {
                frameIndex += 1
            }
        case .once:
            if frameIndex == lastIndex {
                isFinished = true
                unusedTime = timeInFrame / rate
                timeInFrame = 0
                events.append(AnimationEvent(clip: clip.name, frameIndex: lastIndex, kind: .finished))
                return false
            }
            frameIndex += 1
        case .pingPong:
            if lastIndex == 0 {
                events.append(AnimationEvent(clip: clip.name, frameIndex: 0, kind: .loopCompleted))
            } else {
                if pingPongForward, frameIndex == lastIndex { pingPongForward = false }
                frameIndex += pingPongForward ? 1 : -1
                if !pingPongForward, frameIndex == 0 {
                    pingPongForward = true
                    events.append(AnimationEvent(clip: clip.name, frameIndex: 0, kind: .loopCompleted))
                }
            }
        }
        enter(frameIndex, into: &events)
        return true
    }

    private func enter(_ index: Int, into events: inout [AnimationEvent]) {
        for name in clip.frames[index].events {
            events.append(AnimationEvent(clip: clip.name, frameIndex: index, kind: .frame(name)))
        }
    }

    /// Repeating clips return to the same phase after a whole cycle, so a huge step keeps the phase but
    /// drops the events of all but `maxCyclesPerStep` cycles instead of looping thousands of times.
    private func skippingWholeCycles(_ time: Double) -> Double {
        let cycle = cycleDuration
        guard clip.playback != .once, cycle > 0, time > Self.maxCyclesPerStep * cycle else { return time }
        return time - ((time / cycle).rounded(.down) - Self.maxCyclesPerStep) * cycle
    }

    /// Time until the clip is back at the same frame and phase: one pass for `loop`, a round trip for
    /// `pingPong` (end frames are not repeated).
    private var cycleDuration: Double {
        let frames = clip.frames
        switch clip.playback {
        case .loop, .once:
            return clip.duration
        case .pingPong:
            guard frames.count > 1 else { return clip.duration }
            return 2 * clip.duration - frames[0].duration - frames[frames.count - 1].duration
        }
    }
}
