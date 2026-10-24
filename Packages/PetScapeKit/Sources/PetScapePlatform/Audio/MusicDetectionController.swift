import PetScapeCore

/// Opt-in lifecycle, generation fence and session hysteresis. No hardware is touched by initialization.
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
        isRunning = true
        source.onScore = { [weak self] confidence, duration in
            guard let self, self.isRunning, self.generation == token else { return }
            let edge = self.detector.observe(confidence: confidence, duration: duration)
            self.requiresSilenceOnStart = self.detector.isPlaying || self.detector.isAwaitingSilence
            if let edge { self.onMusicChange?(edge) }
        }
        source.onFailure = { [weak self] in
            guard let self, self.isRunning, self.generation == token else { return }
            // Mark failure before notifying Runtime: its render refresh may reenter update().
            self.failed = true
            self.stop()
            self.setStatus(.unavailable)
        }
        do {
            try source.start()
            guard isRunning, generation == token else { return }
            setStatus(.monitoring)
        } catch {
            failed = true
            stop()
            setStatus(.unavailable)
        }
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
