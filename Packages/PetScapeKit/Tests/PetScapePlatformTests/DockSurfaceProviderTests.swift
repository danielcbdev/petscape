import CoreGraphics
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

/// T6.2/T6.3: the walkway follows the screens and the offset; the host screen follows the Dock.
@Suite("DockSurfaceProvider")
struct DockSurfaceProviderTests {
    static let primaryFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)
    static let externalFrame = CGRect(x: 1470, y: 0, width: 1920, height: 1080)

    static func screen(_ id: UInt32, frame: CGRect, bottom: CGFloat = 0, left: CGFloat = 0, isPrimary: Bool = false)
        -> ScreenDescriptor
    {
        ScreenDescriptor(
            id: ScreenID(id), frame: frame,
            visibleFrame: CGRect(
                x: frame.minX + left, y: frame.minY + bottom, width: frame.width - left,
                height: frame.height - bottom - 24),
            backingScale: 2, isPrimary: isPrimary)
    }

    @Test func withoutScreensThereIsNoWalkwayOrHost() {
        let provider = DockSurfaceProvider()
        provider.update(screens: [])
        #expect(provider.surfaces.isEmpty)
        #expect(provider.hostScreenID == nil)
        #expect(provider.estimate == .hiddenOrUnknown)
    }

    @Test func bottomDockGivesTheDockTopWithTheOffsetAndRecomputesWhenItChanges() throws {
        let provider = DockSurfaceProvider(offsetAdjustment: -2)
        provider.update(screens: [Self.screen(1, frame: Self.primaryFrame, bottom: 61, isPrimary: true)])
        #expect(provider.surfaces == [Surface(id: .dock, kind: .dockTop, y: 59, minX: 0, maxX: 1470)])
        #expect(provider.hostScreenID == ScreenID(1))

        provider.offsetAdjustment = 99
        #expect(provider.offsetAdjustment == 40)
        #expect(provider.surface?.y == 101)
    }

    @Test func dockResizedHiddenAndMovedFollowTheScreens() {
        let provider = DockSurfaceProvider()
        let primary = { (bottom: CGFloat, left: CGFloat) in
            Self.screen(1, frame: Self.primaryFrame, bottom: bottom, left: left, isPrimary: true)
        }
        provider.update(screens: [primary(61, 0)])
        provider.update(screens: [primary(42, 0)])  // smaller Dock: same surface ID, lower
        #expect(provider.surface == Surface(id: .dock, kind: .dockTop, y: 42, minX: 0, maxX: 1470))

        provider.update(screens: [primary(0, 0)])  // auto-hide on
        #expect(provider.estimate == .hiddenOrUnknown)
        #expect(provider.surface?.id == .screenBottom(of: ScreenID(1)))

        provider.update(screens: [primary(0, 49)])  // Dock on the left
        #expect(provider.estimate.position == .left)
        #expect(provider.surface == .screenBottom(of: primary(0, 49)))
    }

    @Test func theHostIsTheDockScreenOrThePrimaryWhenHidden() {
        let provider = DockSurfaceProvider()
        let primary = Self.screen(1, frame: Self.primaryFrame, isPrimary: true)
        provider.update(screens: [primary, Self.screen(2, frame: Self.externalFrame, bottom: 58)])
        #expect(provider.hostScreenID == ScreenID(2))
        #expect(provider.surface?.y == 58)
        #expect(provider.surface?.minX == 1470)

        provider.update(screens: [primary, Self.screen(2, frame: Self.externalFrame)])
        #expect(provider.hostScreenID == ScreenID(1))
        #expect(provider.surface?.id == .screenBottom(of: ScreenID(1)))
    }
}
