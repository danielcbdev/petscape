import CoreGraphics

/// Immutable launch prediction, verified with the exact stepper used by the world. Not a second body.
struct JumpPlan: Equatable, Sendable {
    let requestedTarget: CGPoint
    let target: Surface
    let initialVelocity: CGVector
    let impactPosition: CGPoint
    let flightDuration: Double
    let apexRise: CGFloat
}
