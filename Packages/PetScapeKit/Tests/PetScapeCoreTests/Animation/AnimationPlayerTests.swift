import Foundation
import Testing

@testable import PetScapeCore

@Suite("AnimationPlayer")
struct AnimationPlayerTests {
    // MARK: Frame-rate independence (FR-06, AC-06)

    /// Stepping at 60 or 120 Hz, a loop of `frameCount` frames at `fps` shows frame
    /// `floor(t × fps) mod frameCount` at every step, for 10 s of simulated time.
    @Test(arguments: [8, 12, 16, 24, 32], [60, 120])
    func loopFrameFollowsSimulationTime(frameCount: Int, stepsPerSecond: Int) {
        for fps in [9, 12, 24] {
            var player = AnimationPlayer(clip: Fixtures.clip(frameCount: frameCount, fps: Double(fps)))
            let dt = 1 / Double(stepsPerSecond)
            var loops = 0
            for step in 1...(10 * stepsPerSecond) {
                loops += player.advance(by: dt).filter { $0.kind == .loopCompleted }.count
                // Integer arithmetic: floor(step / stepsPerSecond × fps).
                let framesElapsed = step * fps / stepsPerSecond
                #expect(player.frameIndex == framesElapsed % frameCount, "fps \(fps), step \(step)")
                #expect(loops == framesElapsed / frameCount)
            }
        }
    }

    @Test func theCatWalkMatchesAC06At60And120Hz() {
        let walk = Fixtures.clip("walk", frameCount: 8, fps: 9)
        var at60 = AnimationPlayer(clip: walk)
        var at120 = AnimationPlayer(clip: walk)
        for step in 1...600 {
            _ = at60.advance(by: 1.0 / 60)
            _ = at120.advance(by: 1.0 / 120)
            _ = at120.advance(by: 1.0 / 120)
            #expect(at60.frameIndex == (step * 9 / 60) % 8)
            #expect(at120.frameIndex == at60.frameIndex)
        }
    }

    @Test func doesNotDriftOverTenMinutes() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 9))
        let steps = 10 * 60 * 60
        for _ in 0..<steps { _ = player.advance(by: 1.0 / 60) }
        #expect(player.frameIndex == (steps * 9 / 60) % 8)
    }

    // MARK: Playback modes

    @Test func onceHoldsTheLastFrameAndFinishesOnce() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 3, fps: 10, playback: .once))
        var events: [AnimationEvent] = []
        for _ in 0..<10 { player.advance(by: 0.05, into: &events) }  // 0.5 s, clip lasts 0.3 s

        #expect(player.isFinished)
        #expect(player.frameIndex == 2)
        #expect(events == [AnimationEvent(clip: "clip", frameIndex: 2, kind: .finished)])
        let stepEvents1 = player.advance(by: 1)
        #expect(stepEvents1.isEmpty)
        #expect(player.frameIndex == 2)
    }

    @Test func onceReportsTheTimeLeftAfterFinishing() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 2, fps: 10, playback: .once))
        _ = player.advance(by: 0.25)
        #expect(player.isFinished)
        #expect(abs(player.unusedTime - 0.05) < 1e-9)
    }

    @Test func pingPongReversesWithoutRepeatingEndFrames() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 4, fps: 10, playback: .pingPong))
        var indices: [Int] = []
        var loops: [Int] = []
        for step in 1...12 {
            let events = player.advance(by: 0.1)
            indices.append(player.frameIndex)
            if events.contains(where: { $0.kind == .loopCompleted }) { loops.append(step) }
        }
        #expect(indices == [1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0])
        #expect(loops == [6, 12])
    }

    @Test func pingPongWithTwoFramesAlternates() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 2, fps: 10, playback: .pingPong))
        var indices: [Int] = []
        for _ in 1...4 {
            _ = player.advance(by: 0.1)
            indices.append(player.frameIndex)
        }
        #expect(indices == [1, 0, 1, 0])
    }

    @Test(arguments: [AnimationClip.Playback.loop, .pingPong])
    func aSingleFrameClipCompletesALoopPerDuration(_ playback: AnimationClip.Playback) {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 1, fps: 4, playback: playback))
        let events = player.advance(by: 1)
        #expect(player.frameIndex == 0)
        #expect(events.filter { $0.kind == .loopCompleted }.count == 4)
    }

    // MARK: Timing

    @Test func perFrameDurationsAreHonored() {
        var player = AnimationPlayer(clip: Fixtures.clip(durations: [0.1, 0.3, 0.2]))
        var indices: [Int] = []
        for _ in 1...7 {
            _ = player.advance(by: 0.1)
            indices.append(player.frameIndex)
        }
        // Frame 0: [0, 0.1), frame 1: [0.1, 0.4), frame 2: [0.4, 0.6), then frame 0 again.
        #expect(indices == [1, 1, 1, 2, 2, 0, 1])
    }

    @Test func rateScalesPlayback() {
        var fast = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 10), rate: 2)
        _ = fast.advance(by: 0.2)
        #expect(fast.frameIndex == 4)

        var slow = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 10))
        slow.rate = 0.5
        _ = slow.advance(by: 0.4)
        #expect(slow.frameIndex == 2)
    }

    @Test func zeroOrNegativeRateFreezesThePlayer() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 10))
        player.rate = 0
        _ = player.advance(by: 1)
        #expect(player.frameIndex == 0)
        player.rate = -3
        #expect(player.rate == 0)
        _ = player.advance(by: 1)
        #expect(player.frameIndex == 0)
    }

    @Test(arguments: [0.0, -0.1, Double.nan, Double.infinity])
    func invalidStepsDoNotAdvance(_ dt: Double) {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 10))
        _ = player.advance(by: dt)
        #expect(player.frameIndex == 0)
    }

    @Test func notSteppingMeansNotAdvancing() {
        // Pausing the simulation is simply not calling `advance`; nothing reads a wall clock.
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 10))
        _ = player.advance(by: 0.15)
        let snapshot = player
        #expect(player == snapshot)
        _ = player.advance(by: 0.05)
        #expect(player.frameIndex == 2)
    }

    // MARK: Events

    @Test func entryEventsOfTheFirstFrameAreEmittedOnTheFirstStep() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 4, fps: 10, events: [0: ["start"]]))
        let stepEvents2 = player.advance(by: 0)
        #expect(stepEvents2 == [AnimationEvent(clip: "clip", frameIndex: 0, kind: .frame("start"))])
        let stepEvents3 = player.advance(by: 0)
        #expect(stepEvents3.isEmpty)
    }

    @Test func aLongStepEmitsEveryCrossedEventInOrder() {
        let clip = Fixtures.clip(
            "walk", frameCount: 8, fps: 9, events: [2: ["footstep"], 6: ["footstep"], 0: ["a", "b"]])
        var player = AnimationPlayer(clip: clip)
        _ = player.advance(by: 0)  // consume frame 0 entry
        let events = player.advance(by: 1.0)  // 9 frames: 1…7, 0, 1

        #expect(player.frameIndex == 1)
        #expect(
            events == [
                AnimationEvent(clip: "walk", frameIndex: 2, kind: .frame("footstep")),
                AnimationEvent(clip: "walk", frameIndex: 6, kind: .frame("footstep")),
                AnimationEvent(clip: "walk", frameIndex: 0, kind: .loopCompleted),
                AnimationEvent(clip: "walk", frameIndex: 0, kind: .frame("a")),
                AnimationEvent(clip: "walk", frameIndex: 0, kind: .frame("b")),
            ])
    }

    @Test func aHugeStepKeepsThePhaseAndBoundsTheWork() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 8, fps: 9, events: [3: ["footstep"]]))
        let events = player.advance(by: 3600 + 2.0 / 9)  // one hour plus two frames
        #expect(player.frameIndex == 2)
        // At most `maxCyclesPerStep` + 1 cycles of events: one footstep and one loopCompleted each.
        #expect(events.count <= 2 * (Int(AnimationPlayer.maxCyclesPerStep) + 1))
    }

    @Test func eventsAppendToTheCallersBuffer() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 2, fps: 10, events: [1: ["x"]]))
        var buffer = [AnimationEvent(clip: "other", frameIndex: 0, kind: .finished)]
        player.advance(by: 0.1, into: &buffer)
        #expect(buffer.count == 2)
        #expect(buffer.last?.kind == .frame("x"))
    }

    // MARK: Control

    @Test func restartGoesBackToFrameZeroAndReemitsItsEvents() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 3, fps: 10, playback: .once, events: [0: ["go"]]))
        _ = player.advance(by: 1)
        #expect(player.isFinished)
        player.restart()
        #expect(!player.isFinished)
        #expect(player.frameIndex == 0)
        let stepEvents4 = player.advance(by: 0)
        #expect(stepEvents4.map(\.kind) == [.frame("go")])
    }

    @Test func jumpingToAFrameEmitsNothing() {
        var player = AnimationPlayer(clip: Fixtures.clip(frameCount: 4, fps: 10, events: [2: ["x"]]))
        player.jump(toFrame: 2)
        #expect(player.frameIndex == 2)
        let stepEvents5 = player.advance(by: 0.05)
        #expect(stepEvents5.isEmpty)
        player.jump(toFrame: 99)
        #expect(player.frameIndex == 3)
    }
}
