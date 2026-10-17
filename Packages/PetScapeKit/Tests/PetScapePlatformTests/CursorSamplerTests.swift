import CoreGraphics
import Testing

@testable import PetScapePlatform

/// Records installs/removals instead of touching `NSEvent`.
final class SpyMouseMonitoring: GlobalMouseMonitoring {
    private(set) var installCount = 0
    private(set) var removed: [Int] = []
    private(set) var handler: (@MainActor (CursorSample) -> Void)?
    var refuses = false

    func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any? {
        guard !refuses else { return nil }
        installCount += 1
        self.handler = handler
        return installCount
    }

    func removeMonitor(_ monitor: Any) {
        removed.append(monitor as? Int ?? -1)
        handler = nil
    }
}

@Suite("CursorSampler lifecycle")
struct CursorSamplerTests {
    @Test func startsOnceAndForwardsMoves() {
        let spy = SpyMouseMonitoring()
        let sampler = CursorSampler(monitoring: spy)
        var received: [CGPoint] = []
        sampler.startMonitoring { received.append($0.location) }
        sampler.startMonitoring { _ in Issue.record("second handler must not be installed") }
        #expect(spy.installCount == 1)
        #expect(sampler.isMonitoring)

        spy.handler?(CursorSample(location: CGPoint(x: 3, y: 4), isButtonDown: false, timestamp: 1))
        #expect(received == [CGPoint(x: 3, y: 4)])
    }

    @Test func stopRemovesTheInstalledMonitorOnce() {
        let spy = SpyMouseMonitoring()
        let sampler = CursorSampler(monitoring: spy)
        sampler.stopMonitoring()  // nothing installed: no-op
        #expect(spy.removed.isEmpty)

        sampler.startMonitoring { _ in }
        sampler.stopMonitoring()
        sampler.stopMonitoring()
        #expect(spy.removed == [1])
        #expect(!sampler.isMonitoring)
    }

    @Test func canRestartAfterStop() {
        let spy = SpyMouseMonitoring()
        let sampler = CursorSampler(monitoring: spy)
        sampler.startMonitoring { _ in }
        sampler.stopMonitoring()
        sampler.startMonitoring { _ in }
        #expect(spy.installCount == 2)
        #expect(sampler.isMonitoring)
    }

    @Test func refusedMonitorLeavesTheSamplerStopped() {
        let spy = SpyMouseMonitoring()
        spy.refuses = true
        let sampler = CursorSampler(monitoring: spy)
        sampler.startMonitoring { _ in }
        #expect(!sampler.isMonitoring)
    }
}
