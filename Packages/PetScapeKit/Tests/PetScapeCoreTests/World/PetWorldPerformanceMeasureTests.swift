import XCTest

@testable import PetScapeCore

/// M14 local XCTest measurement; intentionally has no wall-time pass/fail threshold for CI.
final class PetWorldPerformanceMeasureTests: XCTestCase {
    func testRepresentativeWorldStepCost() throws {
        let (initialWorld, _) = try PetWorldTests.makeWorld(seed: 14)
        measure {
            var world = initialWorld
            var events: [WorldEvent] = []
            for _ in 0..<600 {
                world.step(dt: 1.0 / 60, into: &events)
                events.removeAll(keepingCapacity: true)
            }
        }
    }
}
