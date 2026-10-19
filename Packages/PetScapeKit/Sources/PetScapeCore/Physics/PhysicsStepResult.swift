import CoreGraphics

/// Ephemeral candidate computed by physics; only PetWorld may commit it to the pet (ADR-0016).
struct PhysicsStepResult: Equatable, Sendable {
    let position: CGPoint
    let velocity: CGVector
    let attachment: SurfaceAttachment?
    let edgeReached: Bool
    let landedSurfaceID: SurfaceID?

    init(
        position: CGPoint, velocity: CGVector, attachment: SurfaceAttachment? = nil,
        edgeReached: Bool = false, landedSurfaceID: SurfaceID? = nil
    ) {
        self.position = position
        self.velocity = velocity
        self.attachment = attachment
        self.edgeReached = edgeReached
        self.landedSurfaceID = landedSurfaceID
    }
}
