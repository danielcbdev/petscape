import CoreGraphics
import PetScapeCore
import PetScapePlatform
import PetScapeRendering

/// MainActor event reducer that gives one PetWorld session ownership of a primary-button gesture.
/// Native window routing remains injected so the controller can be validated without adopting a topology.
public final class InteractionController {
    private let hitTest: (CGPoint) -> PetID?
    private let footPosition: (PetID) -> CGPoint?
    private let submit: (PetID, InteractionCommand) -> Bool
    private let setCapture: (InteractionID?) -> Void
    private var session: InteractionSession
    private var nextID: UInt64 = 1

    public init(
        hitTest: @escaping (CGPoint) -> PetID?,
        footPosition: @escaping (PetID) -> CGPoint?,
        submit: @escaping (PetID, InteractionCommand) -> Bool,
        setCapture: @escaping (InteractionID?) -> Void,
        tuning: InteractionTuning = .default
    ) {
        self.hitTest = hitTest
        self.footPosition = footPosition
        self.submit = submit
        self.setCapture = setCapture
        session = InteractionSession(tuning: tuning)
    }

    public var phase: InteractionSession.Phase { session.phase }

    public func handle(_ event: OverlayMouseEvent) {
        switch event.kind {
        case .moved:
            break
        case .down:
            guard event.button == .primary, case .idle = session.phase, nextID != 0,
                let petID = hitTest(event.location), let foot = footPosition(petID)
            else { return }
            let id = InteractionID(nextID)
            nextID = nextID == .max ? 0 : nextID + 1
            guard let command = session.press(petID: petID, id: id, location: event.location, foot: foot),
                submit(petID, command)
            else {
                _ = session.cancel(.captureLost)
                return
            }
            setCapture(id)
        case .dragged:
            guard event.button == .primary, let petID = activePetID,
                let command = session.move(to: event.location)
            else { return }
            if !submit(petID, command) { cancel(.captureLost) }
        case .up:
            guard event.button == .primary else { return }
            finish(at: event.location)
        }
    }

    public func update(with sample: CursorSample) {
        guard let petID = activePetID else { return }
        if sample.isPrimaryButtonDown {
            if let command = session.move(to: sample.location), !submit(petID, command) {
                cancel(.captureLost)
            }
        } else {
            finish(at: sample.location)
        }
    }

    public func cancel(_ reason: InteractionCancellation) {
        guard let petID = activePetID, let command = session.cancel(reason) else { return }
        _ = submit(petID, command)
        setCapture(nil)
    }

    /// Cancels native capture only when the requested pet owns the active pointer session.
    public func cancel(_ reason: InteractionCancellation, for petID: PetID) {
        guard activePetID == petID else { return }
        cancel(reason)
    }

    private var activePetID: PetID? {
        switch session.phase {
        case .idle: nil
        case .pressed(let petID, _), .dragging(let petID, _): petID
        }
    }

    private func finish(at location: CGPoint) {
        guard let petID = activePetID else { return }
        let command = session.release(at: location, hitPet: hitTest(location))
        if let command { _ = submit(petID, command) }
        setCapture(nil)
    }
}
