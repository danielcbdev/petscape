/// Something that happened in a step (pet-engine.md#events): used for logging, debug views and tests.
public enum WorldEvent: Equatable, Sendable {
    /// Placed on a surface (spawn or respawn).
    case placed(PetID, SurfaceID)
    case stateChanged(PetID, from: PetStateKind, to: PetStateKind)
    /// The contact point reached the walkable end of its surface.
    case edgeReached(PetID)
    case surfaceLost(PetID, SurfaceID)
    case landed(PetID, SurfaceID)
    case tookOff(PetID)
    case apex(PetID)
    case jumpRejected(PetID, JumpRejection)
    case jumpCancelled(PetID)
    case recovered(PetID, reason: RecoveryReason)
    case animationEvent(PetID, AnimationEvent)
}
