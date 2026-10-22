import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("Cursor interest")
struct CursorInterestTests {
    private let context = CursorInterestContext(
        spriteRect: CGRect(x: 0, y: 0, width: 96, height: 96), scale: 1,
        curiosity: 0.5, energy: 1, isEligible: true, expressionsEnabled: true)

    @Test func dwellStartsOneBoundedObservation() {
        var interest = CursorInterest()
        #expect(interest.advance(location: CGPoint(x: 200, y: 48), dt: 0.34, context: context) == nil)
        #expect(
            interest.advance(location: CGPoint(x: 200, y: 48), dt: 0.01, context: context)
                == .began(location: CGPoint(x: 200, y: 48), duration: 2))
        #expect(interest.isObserving)
    }

    @Test func enterAndExitRadiiHaveHysteresis() {
        var interest = CursorInterest()
        let near = CGPoint(x: 200, y: 48)
        _ = interest.advance(location: near, dt: 0.35, context: context)
        #expect(interest.advance(location: CGPoint(x: 250, y: 48), dt: 0.1, context: context) == nil)
        #expect(interest.isObserving)
    }

    @Test func sleepFlightLowEnergyAndDisabledExpressionsDoNotReact() {
        var interest = CursorInterest()
        let location = CGPoint(x: 48, y: 48)
        let contexts = [
            CursorInterestContext(
                spriteRect: context.spriteRect, scale: 1, curiosity: 0.5, energy: 0.25, isEligible: true,
                expressionsEnabled: true),
            CursorInterestContext(
                spriteRect: context.spriteRect, scale: 1, curiosity: 0.5, energy: 1, isEligible: false,
                expressionsEnabled: true),
            CursorInterestContext(
                spriteRect: context.spriteRect, scale: 1, curiosity: 0.5, energy: 1, isEligible: true,
                expressionsEnabled: false),
        ]
        for blocked in contexts {
            #expect(interest.advance(location: location, dt: 1, context: blocked) == nil)
        }
    }

    @Test func invalidTimeDoesNotAdvanceState() {
        var interest = CursorInterest()
        #expect(interest.advance(location: .zero, dt: .infinity, context: context) == nil)
        #expect(!interest.isObserving)
    }

    @Test func personalityScalesObservationDurationAndCapsAtThreeSeconds() {
        for (curiosity, expected) in [(0.0, 1.0), (0.5, 2.0), (1.0, 3.0)] {
            var interest = CursorInterest()
            let context = CursorInterestContext(
                spriteRect: self.context.spriteRect, scale: 1, curiosity: curiosity, energy: 1,
                isEligible: true, expressionsEnabled: true)
            let event = interest.advance(location: CGPoint(x: 200, y: 48), dt: 0.35, context: context)
            #expect(event == .began(location: CGPoint(x: 200, y: 48), duration: expected))
        }
    }

    @Test func exitGraceAndCooldownPreventImmediateRepeat() {
        var interest = CursorInterest()
        let near = CGPoint(x: 200, y: 48)
        let far = CGPoint(x: 257, y: 48)
        #expect(interest.advance(location: near, dt: 0.35, context: context) == .began(location: near, duration: 2))
        for _ in 0..<121 { _ = interest.advance(location: near, dt: 1.0 / 60, context: context) }
        for _ in 0..<46 { _ = interest.advance(location: far, dt: 1.0 / 60, context: context) }
        var repeated = false
        for _ in 0..<428 {
            if case .began? = interest.advance(location: near, dt: 1.0 / 60, context: context) {
                repeated = true
            }
        }
        #expect(!repeated)
        for _ in 0..<30 {
            if case .began? = interest.advance(location: near, dt: 1.0 / 60, context: context) {
                repeated = true
            }
        }
        #expect(repeated)
    }
}
