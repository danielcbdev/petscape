/// Environment changes fed to `PetWorld.apply(_:)` between steps (data-flow.md: batched, never mid-step).
public enum WorldInput: Equatable, Sendable {
    case configureBehavior(AutonomySettings)
    case setDisplayScale(Double)
    case setSpeedScale(Double)
    case wake(PetID)
    case requestJump(PetID, JumpRequest)
    case setActivity(PetID, ResumeActivity)
    /// The connected screens (bounds for the out-of-bounds invariant).
    case screens([ScreenDescriptor])
    /// The complete set of surfaces; applied as a diff (moved surfaces keep attached pets).
    case surfaces([Surface])
}
