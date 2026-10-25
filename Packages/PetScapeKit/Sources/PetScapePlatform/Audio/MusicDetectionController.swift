import PetScapeCore

/// Opt-in lifecycle, generation fence and session hysteresis. No hardware is touched by initialization.
@MainActor
public final class MusicDetectionController {
    public private(set) var status: MusicDetectionStatus = .off
    public var onStatusChange: ((MusicDetectionStatus) -> Void)?
    public var onMusicChange: ((Bool) -> Void)?
    private let source: any MusicScoreSource
    private var detector = MusicSessionDetector()
    private var generation = 0
    private var isRunning = false
    private var requiresSilenceOnStart = false
    private var failed = false
    private var didLogFirstClassification = false

    public init(source: any MusicScoreSource = SystemMusicScoreSource()) { self.source = source }

    public func update(enabled: Bool, canRun: Bool) {
        if enabled, failed {
            setStatus(.unavailable)
            return
        }
        guard enabled, canRun else {
            if isRunning { stop() }
            if !enabled { failed = false }
            setStatus(enabled ? .suspended : .off)
            return
        }
        guard !isRunning, !failed else { return }
        generation += 1
        let token = generation
        detector.reset(requireSilence: requiresSilenceOnStart)
        didLogFirstClassification = false
        isRunning = true
        source.onScore = { [weak self] confidence, duration in
            guard let self, self.isRunning, self.generation == token else { return }
            if !self.didLogFirstClassification {
                self.didLogFirstClassification = true
                Log.permissions.notice("System audio classifier produced its first result")
            }
            let edge = self.detector.observe(confidence: confidence, duration: duration)
            self.requiresSilenceOnStart = self.detector.isPlaying || self.detector.isAwaitingSilence
            if let edge { self.onMusicChange?(edge) }
        }
        source.onFailure = { [weak self] in
            guard let self, self.isRunning, self.generation == token else { return }
            // Mark failure before notifying Runtime: its render refresh may reenter update().
            Log.permissions.error("System audio capture reported a runtime failure")
            self.failed = true
            self.stop()
            self.setStatus(.unavailable)
        }
        do {
            try source.start()
            guard isRunning, generation == token else { return }
            Log.permissions.notice("System audio capture source started")
            setStatus(.monitoring)
        } catch {
            Log.permissions.error("System audio capture source failed to start")
            failed = true
            stop()
            setStatus(.unavailable)
        }
    }

    /// Retries a failed or silent capture after an explicit lifecycle/user recovery action.
    /// The persisted opt-in stays unchanged, and a confirmed session still requires silence to re-arm.
    public func retry(enabled: Bool, canRun: Bool) {
        failed = false
        if isRunning { stop() }
        update(enabled: enabled, canRun: canRun)
    }

    public func stop() {
        generation += 1
        source.onScore = nil
        source.onFailure = nil
        if isRunning { source.stop() }
        isRunning = false
        let wasPlaying = detector.isPlaying
        detector.reset(requireSilence: requiresSilenceOnStart)
        setStatus(.off)
        if wasPlaying { onMusicChange?(false) }
    }

    private func setStatus(_ value: MusicDetectionStatus) {
        guard status != value else { return }
        status = value
        onStatusChange?(value)
    }

    isolated deinit { source.stop() }
}
