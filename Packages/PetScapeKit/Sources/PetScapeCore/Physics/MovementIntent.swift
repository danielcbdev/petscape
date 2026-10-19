import CoreGraphics

/// Movement policy input for world-owned physics (M7); never owns or changes a pet position.
enum MovementIntent: Equatable, Sendable {
    case hold
    /// Nonnegative points/s magnitude; direction is explicit.
    case walk(speed: Double, facing: Facing)
    /// Additional acceleration in points/s²; gravity is applied separately by PhysicsStepper.
    case airborne(acceleration: CGVector)
}
