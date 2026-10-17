import Testing

@testable import PetScapeCore

/// T5.2: fixed 1/60 s steps from display frames (ADR-0013).
@Suite("FixedStepAccumulator")
struct FixedStepAccumulatorTests {
    /// Steps produced by frames every `interval` seconds over `duration`.
    static func totalSteps(interval: Double, duration: Double) -> Int {
        var accumulator = FixedStepAccumulator()
        var total = accumulator.steps(forFrameAt: 1000)
        let frames = Int((duration / interval).rounded())
        for frame in 1...frames {
            total += accumulator.steps(forFrameAt: 1000 + Double(frame) * interval)
        }
        return total
    }

    @Test func firstFrameOnlyRecordsTheTimestamp() {
        var accumulator = FixedStepAccumulator()
        #expect(accumulator.steps(forFrameAt: 50) == 0)
        #expect(accumulator.lastTimestamp == 50)
    }

    @Test(arguments: [60.0, 120, 30, 48])
    func simulatesWallTimeAtAnyDisplayRate(hertz: Double) {
        // 10 s of frames → 600 steps (± 1 for the fraction still accumulated).
        let steps = Self.totalSteps(interval: 1 / hertz, duration: 10)
        #expect(abs(steps - 600) <= 1)
    }

    @Test func sixtyHertzFramesGiveExactlyOneStepEach() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 0)
        for frame in 1...600 {
            #expect(accumulator.steps(forFrameAt: Double(frame) / 60) == 1)
        }
    }

    @Test func oneHundredTwentyHertzFramesAlternate() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 0)
        let steps = (1...8).map { accumulator.steps(forFrameAt: Double($0) / 120) }
        #expect(steps == [0, 1, 0, 1, 0, 1, 0, 1])
    }

    @Test func longFramesAreCappedAtFiveStepsAndTheBacklogIsDropped() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 0)
        #expect(accumulator.steps(forFrameAt: 0.2) == 5)  // 12 steps' worth
        #expect(accumulator.accumulated < accumulator.step)
        #expect(accumulator.steps(forFrameAt: 0.2 + 1.0 / 60) == 1)  // no catch-up afterwards
    }

    @Test func stallsAreClampedToAQuarterSecond() {
        var accumulator = FixedStepAccumulator(maxStepsPerFrame: 100)
        _ = accumulator.steps(forFrameAt: 0)
        #expect(accumulator.steps(forFrameAt: 30) == 15)  // 0.25 s, not 30 s
    }

    @Test func resetForgetsTimeSoResumingDoesNotCatchUp() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 0)
        _ = accumulator.steps(forFrameAt: 0.01)
        accumulator.reset()
        #expect(accumulator.accumulated == 0)
        #expect(accumulator.lastTimestamp == nil)
        #expect(accumulator.steps(forFrameAt: 500) == 0)  // resumed 500 s later
        #expect(accumulator.steps(forFrameAt: 500 + 1.0 / 60) == 1)
    }

    @Test func backwardsOrInvalidTimestampsProduceNoSteps() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 10)
        #expect(accumulator.steps(forFrameAt: 9) == 0)
        #expect(accumulator.steps(forFrameAt: .nan) == 0)
        #expect(accumulator.accumulated == 0)
    }

    @Test func interpolationIsTheUnsimulatedFraction() {
        var accumulator = FixedStepAccumulator()
        _ = accumulator.steps(forFrameAt: 0)
        _ = accumulator.steps(forFrameAt: 1.0 / 120)
        #expect(abs(accumulator.interpolation - 0.5) < 1e-9)
    }
}
