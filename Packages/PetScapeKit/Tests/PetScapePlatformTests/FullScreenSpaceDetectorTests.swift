import AppKit
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

@Suite("FullScreenSpaceDetector")
struct FullScreenSpaceDetectorTests {
    static let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
    static let desktop = [
        WindowListEntry(ownerName: "Dock", layer: dockLevel), WindowListEntry(ownerName: "Finder", layer: 0),
    ]
    static let fullScreen = [WindowListEntry(ownerName: "Safari", layer: 0)]

    /// Window lists returned by successive reads; the last one repeats.
    final class ScriptedReader {
        var script: [[WindowListEntry]?]
        private(set) var readCount = 0

        init(_ script: [[WindowListEntry]?]) {
            self.script = script
        }

        func read() -> [WindowListEntry]? {
            defer { readCount += 1 }
            return script[min(readCount, script.count - 1)]
        }
    }

    static func makeDetector(_ reader: ScriptedReader, center: NotificationCenter) -> FullScreenSpaceDetector {
        FullScreenSpaceDetector(
            workspaceCenter: center, settleDelay: .milliseconds(1), confirmationDelay: .milliseconds(1),
            readWindowList: { reader.read() })
    }

    @Test func initialCheckDetectsALaunchInAFullScreenSpace() async {
        let reader = ScriptedReader([Self.fullScreen])
        let detector = Self.makeDetector(reader, center: NotificationCenter())
        var changes: [Bool] = []
        detector.start { changes.append($0) }
        await waitUntil { changes == [true] }
        #expect(changes == [true])
        #expect(detector.spaceKind == .fullScreen)
        detector.stop()
    }

    @Test func spaceChangeToFullScreenAndBack() async {
        let center = NotificationCenter()
        let reader = ScriptedReader([Self.desktop])
        let detector = Self.makeDetector(reader, center: center)
        var changes: [Bool] = []
        detector.start { changes.append($0) }
        await waitUntil { reader.readCount >= 2 }
        #expect(changes.isEmpty)  // desktop at launch: nothing to report

        reader.script = [Self.fullScreen]
        center.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        await waitUntil { changes == [true] }

        reader.script = [Self.desktop]
        center.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        await waitUntil { changes == [true, false] }
        #expect(changes == [true, false])
        detector.stop()
    }

    @Test func disagreeingReadsKeepTheCurrentDecision() async {
        // Initial check: desktop, then absent → inconclusive.
        let reader = ScriptedReader([Self.desktop, Self.fullScreen])
        let detector = Self.makeDetector(reader, center: NotificationCenter())
        var changes: [Bool] = []
        detector.start { changes.append($0) }
        await waitUntil { reader.readCount >= 2 }
        try? await Task.sleep(for: .milliseconds(20))
        #expect(changes.isEmpty)
        #expect(detector.spaceKind == .desktop)
        detector.stop()
    }

    @Test func unavailableWindowListIsNeverEvidence() async {
        let reader = ScriptedReader([nil])
        let detector = Self.makeDetector(reader, center: NotificationCenter())
        var changes: [Bool] = []
        detector.start { changes.append($0) }
        await waitUntil { reader.readCount >= 2 }
        try? await Task.sleep(for: .milliseconds(20))
        #expect(changes.isEmpty)
        detector.stop()
    }

    @Test func stopCancelsPendingChecksAndRemovesTheObserver() async {
        let center = NotificationCenter()
        let reader = ScriptedReader([Self.fullScreen])
        let detector = FullScreenSpaceDetector(
            workspaceCenter: center, settleDelay: .milliseconds(50), confirmationDelay: .milliseconds(50),
            readWindowList: { reader.read() })
        var changes: [Bool] = []
        detector.start { changes.append($0) }
        detector.stop()
        center.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(changes.isEmpty)
        #expect(reader.readCount <= 1)
    }

    @Test func realWindowListIsReadableWithoutPermissions() {
        // Smoke test against the live window server: owner names and layers are available.
        let windows = FullScreenSpaceDetector.onScreenWindows()
        #expect(windows != nil)
    }
}
