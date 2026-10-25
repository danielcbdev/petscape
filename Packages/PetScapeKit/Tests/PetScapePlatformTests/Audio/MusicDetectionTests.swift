import Testing

@testable import PetScapePlatform

@Suite("M16 music detector lifecycle")
struct MusicDetectionTests {
    final class FakeSource: MusicScoreSource {
        var onScore: ((Double, Double) -> Void)?
        var onFailure: (() -> Void)?
        var starts = 0
        var stops = 0
        var failAtStart = false
        func start() throws {
            starts += 1
            if failAtStart { throw MusicCaptureError.unavailable }
        }
        func stop() { stops += 1 }
    }

    @Test func optInLifecycleStopsAndRejectsLateCallbacks() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        var edges: [Bool] = []
        detector.onMusicChange = { edges.append($0) }
        detector.update(enabled: false, canRun: true)
        #expect(source.starts == 0)
        detector.update(enabled: true, canRun: true)
        #expect(source.starts == 1)
        source.onScore?(0.9, 1)
        #expect(edges == [true])
        let stale = source.onScore
        detector.update(enabled: true, canRun: false)
        #expect(source.stops == 1)
        #expect(edges == [true, false])
        stale?(1, 1)
        #expect(edges == [true, false])
        detector.update(enabled: true, canRun: true)
        stale?(0, 1)
        source.onScore?(1, 1)
        #expect(edges == [true, false])
        source.onScore?(0, 1)
        source.onScore?(1, 1)
        #expect(edges == [true, false, true])
        detector.stop()
        #expect(source.onScore == nil)
        #expect(source.onFailure == nil)
        #expect(source.stops == 2)
    }

    @Test func startupSuspensionBeforeAnyMusicDoesNotConsumeTheFirstSession() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        var edges: [Bool] = []
        detector.onMusicChange = { edges.append($0) }
        detector.update(enabled: true, canRun: true)
        detector.update(enabled: true, canRun: false)
        detector.update(enabled: true, canRun: true)
        source.onScore?(1, 1)
        #expect(edges == [true])
    }

    @Test func retryAfterFailedStartCanRecognizeAlreadyPlayingMusic() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        var edges: [Bool] = []
        detector.onMusicChange = { edges.append($0) }
        source.failAtStart = true
        detector.update(enabled: true, canRun: true)
        detector.update(enabled: false, canRun: true)
        source.failAtStart = false
        detector.update(enabled: true, canRun: true)
        source.onScore?(1, 1)
        #expect(edges == [true])
    }

    @Test func explicitRetryRecoversWithoutClearingTheOptInPreference() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        var edges: [Bool] = []
        detector.onMusicChange = { edges.append($0) }
        source.failAtStart = true

        detector.update(enabled: true, canRun: true)
        #expect(detector.status == .unavailable)
        #expect(source.starts == 1)

        source.failAtStart = false
        detector.retry(enabled: true, canRun: true)

        #expect(detector.status == .monitoring)
        #expect(source.starts == 2)
        source.onScore?(0.9, 1)
        #expect(edges == [true])
    }

    @Test func failureCallbackCannotRestartCaptureDuringRuntimeRefresh() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        detector.onMusicChange = { playing in
            if !playing { detector.update(enabled: true, canRun: true) }
        }
        detector.update(enabled: true, canRun: true)
        source.onScore?(1, 1)
        source.onFailure?()
        #expect(source.starts == 1)
        #expect(source.stops == 1)
        #expect(source.onScore == nil)
        #expect(detector.status == .unavailable)
    }

    @Test func latchedFailureRemainsVisibleAcrossSuspensionAndResume() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        source.failAtStart = true
        detector.update(enabled: true, canRun: true)
        detector.update(enabled: true, canRun: false)
        detector.update(enabled: true, canRun: true)
        #expect(detector.status == .unavailable)
        #expect(source.starts == 1)
    }

    @Test func deniedUnavailableAndMidstreamFailureStopSafelyWithoutRetryLoop() {
        let source = FakeSource()
        let detector = MusicDetectionController(source: source)
        source.failAtStart = true
        detector.update(enabled: true, canRun: true)
        #expect(detector.status == .unavailable)
        #expect(source.stops == 1)
        detector.update(enabled: true, canRun: true)
        #expect(source.starts == 1)
        detector.update(enabled: false, canRun: true)
        source.failAtStart = false
        detector.update(enabled: true, canRun: true)
        source.onScore?(1, 1)
        source.onFailure?()
        #expect(detector.status == .unavailable)
        #expect(source.stops == 2)
        #expect(source.onScore == nil)
    }
}
