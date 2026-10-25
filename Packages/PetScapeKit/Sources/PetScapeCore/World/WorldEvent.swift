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
    case interactionAccepted(PetID, InteractionID)
    case interactionEnded(PetID, InteractionID)
    case interactionRejected(PetID, InteractionID)

    public var petID: PetID {
        switch self {
        case .placed(let id, _), .stateChanged(let id, _, _), .edgeReached(let id), .surfaceLost(let id, _),
            .landed(let id, _), .tookOff(let id), .apex(let id), .jumpRejected(let id, _),
            .jumpCancelled(let id), .recovered(let id, _), .animationEvent(let id, _),
            .interactionAccepted(let id, _), .interactionEnded(let id, _), .interactionRejected(let id, _):
            id
        }
    }
}
