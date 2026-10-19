import CoreGraphics

/// Provisional M7 kinematic constants (physics-engine.md). Distances are points, time is seconds.
struct PhysicsTuning: Equatable, Sendable {
    /// Positive downward acceleration magnitude, in points/s².
    let gravity: Double
    /// Maximum downward speed magnitude, in points/s; does not cap upward motion.
    let terminalFallSpeed: Double
    /// Numerical contact tolerance in points, independent of display pixels.
    let contactTolerance: CGFloat
    /// Maximum uninterrupted airborne simulated time, in seconds (future world watchdog).
    let maxAirborneDuration: Double

    init(
        gravity: Double = 2400, terminalFallSpeed: Double = 1800,
        contactTolerance: CGFloat = 1e-6, maxAirborneDuration: Double = 3
    ) {
        self.gravity = gravity
        self.terminalFallSpeed = terminalFallSpeed
        self.contactTolerance = contactTolerance
        self.maxAirborneDuration = maxAirborneDuration
    }

    /// Checked at the step boundary so invalid injected tuning cannot poison simulation state.
    var isValid: Bool {
        gravity.isFinite && gravity > 0
            && terminalFallSpeed.isFinite && terminalFallSpeed > 0
            && contactTolerance.isFinite && contactTolerance > 0
            && maxAirborneDuration.isFinite && maxAirborneDuration > 0
    }
}
