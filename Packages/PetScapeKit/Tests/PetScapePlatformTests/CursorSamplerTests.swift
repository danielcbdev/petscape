import CoreGraphics
import Testing

@testable import PetScapePlatform

final class SpyGlobalMouseMonitoring: GlobalMouseMonitoring {
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

final class SpyLocalMouseMonitoring: LocalMouseMonitoring {
    private(set) var installCount = 0
    private(set) var removed: [Int] = []
    private(set) var handler: (@MainActor (CursorSample) -> Void)?

    func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any? {
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
    @Test func startsBothMonitorsOnceAndForwardsMoves() {
        let global = SpyGlobalMouseMonitoring()
        let local = SpyLocalMouseMonitoring()
        let sampler = CursorSampler(monitoring: global, localMonitoring: local)
        var received: [CGPoint] = []
        sampler.startMonitoring { received.append($0.location) }
        sampler.startMonitoring { _ in Issue.record("second handlers must not be installed") }
        #expect(global.installCount == 1)
        #expect(local.installCount == 1)
        #expect(sampler.isMonitoring)

        global.handler?(CursorSample(location: CGPoint(x: 3, y: 4), isButtonDown: false, timestamp: 1))
        local.handler?(CursorSample(location: CGPoint(x: 5, y: 6), isButtonDown: false, timestamp: 1))
        #expect(received == [CGPoint(x: 3, y: 4), CGPoint(x: 5, y: 6)])
    }

    @Test func stopRemovesBothInstalledMonitorsOnce() {
        let global = SpyGlobalMouseMonitoring()
        let local = SpyLocalMouseMonitoring()
        let sampler = CursorSampler(monitoring: global, localMonitoring: local)
        sampler.stopMonitoring()
        #expect(global.removed.isEmpty)
        #expect(local.removed.isEmpty)

        sampler.startMonitoring { _ in }
        sampler.stopMonitoring()
        sampler.stopMonitoring()
        #expect(global.removed == [1])
        #expect(local.removed == [1])
        #expect(!sampler.isMonitoring)
    }

    @Test func canRestartAfterStop() {
        let global = SpyGlobalMouseMonitoring()
        let local = SpyLocalMouseMonitoring()
        let sampler = CursorSampler(monitoring: global, localMonitoring: local)
        sampler.startMonitoring { _ in }
        sampler.stopMonitoring()
        sampler.startMonitoring { _ in }
        #expect(global.installCount == 2)
        #expect(local.installCount == 2)
        #expect(sampler.isMonitoring)
    }

    @Test func refusedGlobalMonitorLeavesLocalSamplingAvailable() {
        let global = SpyGlobalMouseMonitoring()
        let local = SpyLocalMouseMonitoring()
        global.refuses = true
        let sampler = CursorSampler(monitoring: global, localMonitoring: local)
        sampler.startMonitoring { _ in }
        #expect(sampler.isMonitoring)
        #expect(global.installCount == 0)
        #expect(local.installCount == 1)
    }

    @Test func callbackCapturedBeforeStopIsIgnoredAfterStop() {
        let global = SpyGlobalMouseMonitoring()
        let local = SpyLocalMouseMonitoring()
        let sampler = CursorSampler(monitoring: global, localMonitoring: local)
        var count = 0
        sampler.startMonitoring { _ in count += 1 }
        let lateGlobal = global.handler
        let lateLocal = local.handler
        sampler.stopMonitoring()
        let sample = CursorSample(location: .zero, isButtonDown: false, timestamp: 1)
        lateGlobal?(sample)
        lateLocal?(sample)
        #expect(count == 0)
    }

    @Test func primaryButtonIsIndependentFromAnyButton() {
        let sample = CursorSample(
            location: CGPoint(x: -4, y: 8), isButtonDown: true, timestamp: 2,
            isPrimaryButtonDown: false)
        #expect(sample.location == CGPoint(x: -4, y: 8))
        #expect(sample.isButtonDown)
        #expect(!sample.isPrimaryButtonDown)
    }
}
