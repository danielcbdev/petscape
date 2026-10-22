import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("Interaction session")
struct InteractionSessionTests {
    @Test func pickupStartsAtFourPointThresholdAndPreservesFootOffset() {
        var session = InteractionSession()
        let pet = PetID(7)
        let down = CGPoint(x: 40, y: 50)
        let foot = CGPoint(x: 31, y: 42)
        #expect(session.press(petID: pet, id: InteractionID(1), location: down, foot: foot) == .press(InteractionID(1)))
        #expect(session.move(to: CGPoint(x: 42.9, y: 50)) == nil)
        #expect(session.move(to: CGPoint(x: 43.99, y: 50)) == nil)
        #expect(
            session.move(to: CGPoint(x: 44, y: 50))
                == .beginHold(InteractionID(1), target: CGPoint(x: 35, y: 42)))
        #expect(session.move(to: CGPoint(x: 50, y: 60)) == .moveHold(InteractionID(1), target: CGPoint(x: 41, y: 52)))
    }

    @Test func negativeScreenOriginsPreserveTheExactFootOffset() {
        var session = InteractionSession()
        let id = InteractionID(9)
        let pet = PetID(3)
        let down = CGPoint(x: -120.25, y: 64)
        let foot = CGPoint(x: -149.75, y: 88)

        #expect(session.press(petID: pet, id: id, location: down, foot: foot) == .press(id))
        #expect(
            session.move(to: CGPoint(x: -116.25, y: 64))
                == .beginHold(id, target: CGPoint(x: -145.75, y: 88)))
        #expect(
            session.release(at: CGPoint(x: -101.5, y: 80), hitPet: nil)
                == .release(id, target: CGPoint(x: -131, y: 104)))
    }

    @Test func injectedThresholdAndInvalidTuningUseBoundedDefaults() {
        var session = InteractionSession(tuning: InteractionTuning(dragThreshold: 3.5))
        let id = InteractionID(1)
        _ = session.press(petID: PetID(1), id: id, location: .zero, foot: .zero)
        #expect(session.move(to: CGPoint(x: 3, y: 0)) == nil)
        #expect(session.move(to: CGPoint(x: 3.5, y: 0)) == .beginHold(id, target: CGPoint(x: 3.5, y: 0)))
        #expect(InteractionTuning(dragThreshold: .nan).dragThreshold == 4)
    }

    @Test func releaseDistinguishesClickFromDragAndIsIdempotent() {
        var session = InteractionSession()
        let pet = PetID(2)
        let id = InteractionID(4)
        #expect(session.press(petID: pet, id: id, location: .zero, foot: CGPoint(x: 8, y: 9)) == .press(id))
        #expect(session.release(at: CGPoint(x: 1, y: 1), hitPet: pet) == .click)
        #expect(session.release(at: .zero, hitPet: pet) == nil)

        #expect(session.press(petID: pet, id: id, location: .zero, foot: .zero) == .press(id))
        #expect(session.move(to: CGPoint(x: 4, y: 0)) == .beginHold(id, target: CGPoint(x: 4, y: 0)))
        #expect(session.release(at: CGPoint(x: 12, y: 20), hitPet: nil) == .release(id, target: CGPoint(x: 12, y: 20)))
        #expect(session.phase == .idle)
    }

    @Test func invalidOrCompetingInputDoesNotCreateOrReplaceSession() {
        var session = InteractionSession()
        let id = InteractionID(1)
        #expect(session.press(petID: PetID(1), id: id, location: .zero, foot: .zero) == .press(id))
        #expect(session.press(petID: PetID(2), id: InteractionID(2), location: .zero, foot: .zero) == nil)
        #expect(session.move(to: CGPoint(x: CGFloat.infinity, y: 0)) == nil)
        #expect(session.phase == .pressed(petID: PetID(1), id: id))
        #expect(session.cancel(.paused) == .cancel(id, reason: .paused))
        #expect(session.phase == .idle)
    }
}
