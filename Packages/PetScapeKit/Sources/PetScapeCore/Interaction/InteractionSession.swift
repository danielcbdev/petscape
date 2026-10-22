import CoreGraphics

/// Stable identity for one primary-button interaction. Zero is reserved for an unallocated ID.
public struct InteractionID: Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public var isValid: Bool { rawValue != 0 }
}

public enum InteractionCancellation: Equatable, Sendable {
    case paused, hidden, suspended, spaceChanged, geometryChanged, settingsChanged
    case petUnavailable, captureLost, releasedOutside, stopped
}

/// Commands passed across the Runtime/Core boundary; none mutate a Pet outside PetWorld.
public enum InteractionCommand: Equatable, Sendable {
    case press(InteractionID)
    case beginHold(InteractionID, target: CGPoint)
    case moveHold(InteractionID, target: CGPoint)
    case release(InteractionID, target: CGPoint)
    case cancel(InteractionID, reason: InteractionCancellation)
    case click
    case observeCursor(location: CGPoint)
}

/// Pure primary-button gesture reducer. It tracks pointer geometry and emits world commands only.
public struct InteractionSession: Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case pressed(petID: PetID, id: InteractionID)
        case dragging(petID: PetID, id: InteractionID)
    }

    public private(set) var phase: Phase = .idle
    private var downLocation = CGPoint.zero
    private var footOffset = CGPoint.zero
    private let tuning: InteractionTuning

    public init(tuning: InteractionTuning = .default) { self.tuning = tuning }

    @discardableResult
    public mutating func press(petID: PetID, id: InteractionID, location: CGPoint, foot: CGPoint) -> InteractionCommand?
    {
        guard phase == .idle, id.isValid, location.isFinitePoint, foot.isFinitePoint else { return nil }
        phase = .pressed(petID: petID, id: id)
        downLocation = location
        footOffset = CGPoint(x: foot.x - location.x, y: foot.y - location.y)
        return .press(id)
    }

    @discardableResult
    public mutating func move(to location: CGPoint) -> InteractionCommand? {
        guard location.isFinitePoint else { return nil }
        switch phase {
        case .idle:
            return nil
        case .pressed(let petID, let id):
            guard hypot(location.x - downLocation.x, location.y - downLocation.y) >= tuning.dragThreshold else {
                return nil
            }
            phase = .dragging(petID: petID, id: id)
            return .beginHold(id, target: target(for: location))
        case .dragging(_, let id):
            return .moveHold(id, target: target(for: location))
        }
    }

    @discardableResult
    public mutating func release(at location: CGPoint, hitPet: PetID?) -> InteractionCommand? {
        guard location.isFinitePoint else { return cancel(.captureLost) }
        let command: InteractionCommand?
        switch phase {
        case .idle:
            return nil
        case .pressed(let petID, let id):
            command = hitPet == petID ? .click : .cancel(id, reason: .releasedOutside)
        case .dragging(_, let id):
            command = .release(id, target: target(for: location))
        }
        phase = .idle
        return command
    }

    @discardableResult
    public mutating func cancel(_ reason: InteractionCancellation) -> InteractionCommand? {
        let id: InteractionID
        switch phase {
        case .idle: return nil
        case .pressed(_, let activeID), .dragging(_, let activeID): id = activeID
        }
        phase = .idle
        return .cancel(id, reason: reason)
    }

    private func target(for location: CGPoint) -> CGPoint {
        CGPoint(x: location.x + footOffset.x, y: location.y + footOffset.y)
    }
}

private extension CGPoint {
    var isFinitePoint: Bool { x.isFinite && y.isFinite }
}
