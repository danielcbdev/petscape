import CoreGraphics

struct WindowClimbPlan: Equatable, Sendable {
    let target: Surface
    let initialVelocity: CGVector
    let contactPosition: CGPoint
}
