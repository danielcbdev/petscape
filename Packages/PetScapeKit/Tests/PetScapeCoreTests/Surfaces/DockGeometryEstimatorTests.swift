import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

/// T6.1: the Dock estimator table and the surface selection of surface-detection.md#tests.
@Suite("DockGeometryEstimator")
struct DockGeometryEstimatorTests {
    /// A screen with the menu bar (24 pt) at the top and the given Dock reservations.
    static func screen(
        _ id: UInt32, frame: CGRect, bottom: CGFloat = 0, left: CGFloat = 0, right: CGFloat = 0,
        menuBar: CGFloat = 24, isPrimary: Bool = false
    ) -> ScreenDescriptor {
        let visible = CGRect(
            x: frame.minX + left, y: frame.minY + bottom, width: frame.width - left - right,
            height: frame.height - bottom - menuBar)
        return ScreenDescriptor(
            id: ScreenID(id), frame: frame, visibleFrame: visible, backingScale: 2, isPrimary: isPrimary)
    }

    static let builtIn = CGRect(x: 0, y: 0, width: 1470, height: 956)

    // MARK: Estimate

    @Test func bottomDock() {
        let estimate = DockGeometryEstimator.estimate(screens: [
            Self.screen(1, frame: Self.builtIn, bottom: 70, isPrimary: true)
        ])
        #expect(estimate == DockEstimate(position: .bottom, screenID: ScreenID(1), thickness: 70, edgeLine: 70))
    }

    @Test(arguments: [42, 65] as [CGFloat])
    func bottomDockSizesMeasuredInThePoC(inset: CGFloat) {
        let estimate = DockGeometryEstimator.estimate(screens: [
            Self.screen(1, frame: Self.builtIn, bottom: inset, isPrimary: true)
        ])
        #expect(estimate.position == .bottom)
        #expect(estimate.edgeLine == inset)
    }

    @Test func leftAndRightDocks() {
        let left = DockGeometryEstimator.estimate(screens: [
            Self.screen(1, frame: Self.builtIn, left: 49, isPrimary: true)
        ])
        #expect(left == DockEstimate(position: .left, screenID: ScreenID(1), thickness: 49, edgeLine: 49))
        let right = DockGeometryEstimator.estimate(screens: [
            Self.screen(1, frame: Self.builtIn, right: 49, isPrimary: true)
        ])
        #expect(right == DockEstimate(position: .right, screenID: ScreenID(1), thickness: 49, edgeLine: 1470 - 49))
    }

    @Test(arguments: [0, 1, 4, 9.5] as [CGFloat])
    func autoHideReservesTooLittleToCount(inset: CGFloat) {
        let screens = [Self.screen(1, frame: Self.builtIn, bottom: inset, isPrimary: true)]
        #expect(DockGeometryEstimator.estimate(screens: screens) == .hiddenOrUnknown)
    }

    @Test func theMenuBarAloneIsNotADock() {
        let screens = [Self.screen(1, frame: Self.builtIn, menuBar: 37, isPrimary: true)]
        #expect(DockGeometryEstimator.estimate(screens: screens) == .hiddenOrUnknown)
    }

    @Test func noScreensMeansUnknown() {
        #expect(DockGeometryEstimator.estimate(screens: []) == .hiddenOrUnknown)
    }

    @Test func dockOnTheSecondaryScreen() {
        let primary = Self.screen(1, frame: Self.builtIn, isPrimary: true)
        let external = Self.screen(2, frame: CGRect(x: 1470, y: 0, width: 1920, height: 1080), bottom: 58)
        let estimate = DockGeometryEstimator.estimate(screens: [primary, external])
        #expect(estimate == DockEstimate(position: .bottom, screenID: ScreenID(2), thickness: 58, edgeLine: 58))
    }

    @Test func screensWithNegativeCoordinates() {
        // A display left of and below the primary: global x and y are negative.
        let primary = Self.screen(1, frame: Self.builtIn, isPrimary: true)
        let leftBelow = Self.screen(2, frame: CGRect(x: -1920, y: -300, width: 1920, height: 1080), bottom: 64)
        let estimate = DockGeometryEstimator.estimate(screens: [primary, leftBelow])
        #expect(estimate == DockEstimate(position: .bottom, screenID: ScreenID(2), thickness: 64, edgeLine: -236))

        let leftDock = Self.screen(3, frame: CGRect(x: -1920, y: 200, width: 1920, height: 1080), left: 49)
        let side = DockGeometryEstimator.estimate(screens: [primary, leftDock])
        #expect(side == DockEstimate(position: .left, screenID: ScreenID(3), thickness: 49, edgeLine: -1871))
    }

    @Test func theLargestReservationWinsAndTiesKeepTheFirstScreen() {
        let small = Self.screen(1, frame: Self.builtIn, bottom: 20, isPrimary: true)
        let large = Self.screen(2, frame: CGRect(x: 1470, y: 0, width: 1920, height: 1080), bottom: 70)
        #expect(DockGeometryEstimator.estimate(screens: [small, large]).screenID == ScreenID(2))
        let twin = Self.screen(3, frame: CGRect(x: -1470, y: 0, width: 1470, height: 956), bottom: 20)
        #expect(DockGeometryEstimator.estimate(screens: [small, twin]).screenID == ScreenID(1))
    }

    // MARK: Surface selection

    @Test func bottomDockGivesTheDockTopAcrossTheFullScreenWidth() throws {
        let screens = [Self.screen(1, frame: Self.builtIn, bottom: 70, isPrimary: true)]
        let estimate = DockGeometryEstimator.estimate(screens: screens)
        let surface = try #require(DockGeometryEstimator.surface(for: estimate, screens: screens, offsetAdjustment: 0))
        #expect(surface == Surface(id: .dock, kind: .dockTop, y: 70, minX: 0, maxX: 1470))
        // The world keeps a 96 pt sprite inside: contact points from half its width to the other end.
        #expect(surface.walkableRange(margin: 48) == 48...1422)
    }

    @Test(
        arguments: [(-3.0, 67.0), (12.5, 82.5), (-40, 30), (40, 110), (-55, 30), (90, 110), (.nan, 70)]
            as [(Double, CGFloat)])
    func offsetAdjustmentMovesTheDockTopWithinItsRange(offset: Double, expectedY: CGFloat) throws {
        let screens = [Self.screen(1, frame: Self.builtIn, bottom: 70, isPrimary: true)]
        let estimate = DockGeometryEstimator.estimate(screens: screens)
        let surface = try #require(
            DockGeometryEstimator.surface(for: estimate, screens: screens, offsetAdjustment: offset))
        #expect(surface.y == expectedY)
    }

    @Test func sideDocksGiveTheBottomOfTheDockScreenWithoutTheOffset() throws {
        let primary = Self.screen(1, frame: Self.builtIn, isPrimary: true)
        let external = Self.screen(2, frame: CGRect(x: 1470, y: -100, width: 1920, height: 1080), right: 49)
        let estimate = DockGeometryEstimator.estimate(screens: [primary, external])
        let surface = try #require(
            DockGeometryEstimator.surface(for: estimate, screens: [primary, external], offsetAdjustment: 15))
        #expect(surface == .screenBottom(of: external))
        #expect(surface.kind == .screenBottom)
    }

    @Test func hiddenDockGivesTheBottomOfThePrimaryScreen() throws {
        let external = Self.screen(2, frame: CGRect(x: 1470, y: 0, width: 1920, height: 1080))
        let primary = Self.screen(1, frame: Self.builtIn, isPrimary: true)
        let surface = try #require(
            DockGeometryEstimator.surface(for: .hiddenOrUnknown, screens: [external, primary], offsetAdjustment: 15))
        #expect(surface == .screenBottom(of: primary))
    }

    @Test func anEstimateForAScreenThatIsGoneFallsBackToThePrimaryBottom() throws {
        let primary = Self.screen(1, frame: Self.builtIn, isPrimary: true)
        let stale = DockEstimate(position: .bottom, screenID: ScreenID(9), thickness: 70, edgeLine: 70)
        let surface = try #require(DockGeometryEstimator.surface(for: stale, screens: [primary], offsetAdjustment: 0))
        #expect(surface == .screenBottom(of: primary))
    }

    @Test func noScreensNoSurface() {
        #expect(DockGeometryEstimator.surface(for: .hiddenOrUnknown, screens: [], offsetAdjustment: 0) == nil)
    }
}
