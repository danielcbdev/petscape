import AppKit
import CoreGraphics
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

@Suite("CG window snapshot filtering")
struct CGWindowSnapshotSourceTests {
    @Test func filtersOwnProcessLayerTransparencySizeAndOffscreenFrames() throws {
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: -100, y: 0, width: 100, height: 100),
            visibleFrame: CGRect(x: -100, y: 0, width: 100, height: 90), backingScale: 1, isPrimary: true)
        let converter = try #require(CoordinateConverter(screens: [screen]))
        let entries = [
            entry(id: 1, pid: 99, bounds: CGRect(x: -80, y: 20, width: 60, height: 40)),
            entry(id: 2, pid: 8, bounds: CGRect(x: -80, y: 20, width: 60, height: 40)),
            entry(id: 3, pid: 8, bounds: CGRect(x: -80, y: 20, width: 60, height: 40), layer: 1),
            entry(id: 4, pid: 8, bounds: CGRect(x: -80, y: 20, width: 60, height: 40), alpha: 0),
            entry(id: 5, pid: 8, bounds: CGRect(x: -80, y: 20, width: 30, height: 20)),
            entry(id: 6, pid: 8, bounds: CGRect(x: 500, y: 20, width: 60, height: 40)),
        ]
        let windows = CGWindowSnapshotSource().windows(from: entries, converter: converter, ownPID: 99)
        #expect(windows.map(\.id) == [2])
        #expect(windows[0].frame == converter.globalRect(fromQuartz: QuartzRect(x: -80, y: 20, width: 60, height: 40)))
        #expect(windows[0].zIndex == 1)
    }

    private func entry(
        id: Int, pid: Int, bounds: CGRect, layer: Int = 0, alpha: Double = 1
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: pid,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: alpha,
            kCGWindowBounds as String: bounds.dictionaryRepresentation,
        ]
    }
}
