import CoreGraphics
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

@Suite("ScreenProvider mapping")
struct ScreenProviderTests {
    @Test func firstScreenIsPrimaryAndValuesAreCopied() {
        let raw = [
            ScreenProvider.RawScreen(
                displayID: 1, frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                visibleFrame: CGRect(x: 0, y: 65, width: 1470, height: 858), backingScale: 2),
            ScreenProvider.RawScreen(
                displayID: 7, frame: CGRect(x: -1920, y: -180, width: 1920, height: 1080),
                visibleFrame: CGRect(x: -1920, y: -180, width: 1920, height: 1055), backingScale: 1),
        ]
        let screens = ScreenProvider.descriptors(from: raw)
        #expect(screens.map(\.id) == [ScreenID(1), ScreenID(7)])
        #expect(screens.map(\.isPrimary) == [true, false])
        #expect(screens[1].frame == raw[1].frame)
        #expect(screens[1].visibleFrame == raw[1].visibleFrame)
        #expect(screens.map(\.backingScale) == [2, 1])
    }

    @Test func screensWithoutDisplayIDAreSkippedButPrimaryStaysIndexZero() {
        let raw = [
            ScreenProvider.RawScreen(displayID: nil, frame: .zero, visibleFrame: .zero, backingScale: 1),
            ScreenProvider.RawScreen(
                displayID: 3, frame: CGRect(x: 0, y: 0, width: 10, height: 10), visibleFrame: .zero, backingScale: 1),
        ]
        let screens = ScreenProvider.descriptors(from: raw)
        #expect(screens.map(\.id) == [ScreenID(3)])
        #expect(screens.first?.isPrimary == false)
    }

    @Test func noScreensMapToEmpty() {
        #expect(ScreenProvider.descriptors(from: []).isEmpty)
        #expect(ScreenProvider.summary(of: []) == "no screens")
    }
}
