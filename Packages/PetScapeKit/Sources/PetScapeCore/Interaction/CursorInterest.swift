import CoreGraphics

public struct CursorInterestContext: Equatable, Sendable {
    public var spriteRect: CGRect
    public var scale: Double
    public var curiosity: Double
    public var energy: Double
    public var isEligible: Bool
    public var expressionsEnabled: Bool

    public init(
        spriteRect: CGRect, scale: Double, curiosity: Double, energy: Double,
        isEligible: Bool, expressionsEnabled: Bool
    ) {
        self.spriteRect = spriteRect
        self.scale = scale
        self.curiosity = curiosity
        self.energy = energy
        self.isEligible = isEligible
        self.expressionsEnabled = expressionsEnabled
    }
}

public enum CursorInterestEvent: Equatable, Sendable {
    case began(location: CGPoint, duration: Double)
    case ended
}

/// Fixed-step cursor dwell and bounded observation timing. It does not read the cursor or move a pet.
public struct CursorInterest: Sendable {
    private var dwell = 0.0
    private var outsideExit = 0.0
    private var observationRemaining = 0.0
    private var cooldownRemaining = 0.0
    private var isInterested = false

    public init() {}

    public var isObserving: Bool { observationRemaining > 0 }

    public mutating func cancel() {
        dwell = 0
        outsideExit = 0
        observationRemaining = 0
        isInterested = false
    }

    public mutating func advance(
        location: CGPoint, dt: Double, context: CursorInterestContext
    ) -> CursorInterestEvent? {
        guard dt.isFinite, dt > 0 else { return nil }
        cooldownRemaining = max(0, cooldownRemaining - dt)

        if observationRemaining > 0 {
            observationRemaining = max(0, observationRemaining - dt)
            if observationRemaining == 0 {
                cooldownRemaining = 8
                return .ended
            }
            return nil
        }

        guard context.isEligible, context.expressionsEnabled, context.energy > 0.25,
            context.spriteRect.origin.x.isFinite, context.spriteRect.origin.y.isFinite,
            context.spriteRect.width.isFinite, context.spriteRect.height.isFinite,
            context.scale.isFinite, context.scale > 0
        else {
            dwell = 0
            outsideExit = 0
            isInterested = false
            return nil
        }

        let dx = max(context.spriteRect.minX - location.x, 0, location.x - context.spriteRect.maxX)
        let dy = max(context.spriteRect.minY - location.y, 0, location.y - context.spriteRect.maxY)
        let distance = hypot(dx, dy)
        let enterRadius = 120 * context.scale
        let exitRadius = 160 * context.scale

        if distance >= exitRadius {
            dwell = 0
            outsideExit += dt
            if outsideExit >= 0.75 { isInterested = false }
            return nil
        }
        outsideExit = 0

        if isInterested {
            return nil
        }
        guard distance <= enterRadius, cooldownRemaining == 0 else {
            dwell = 0
            return nil
        }
        dwell += dt
        guard dwell >= 0.35 else { return nil }
        dwell = 0
        isInterested = true
        observationRemaining = min(3, 1 + 2 * min(1, max(0, context.curiosity)))
        return .began(location: location, duration: observationRemaining)
    }
}
