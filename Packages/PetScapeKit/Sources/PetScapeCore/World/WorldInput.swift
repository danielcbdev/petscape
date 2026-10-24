import CoreGraphics

/// Environment changes fed to `PetWorld.apply(_:)` between steps (data-flow.md: batched, never mid-step).
public enum WorldInput: Equatable, Sendable {
    case configureMusicDancing(Bool)
    case setMusicPlaying(Bool)
    case requestDance(PetID)
    case stopDance(PetID)
    case suspendMusicBehaviors
    case configureBehavior(AutonomySettings)
    case setDisplayScale(Double)
    case setSpeedScale(Double)
    case wake(PetID)
    case requestJump(PetID, JumpRequest)
    case setActivity(PetID, ResumeActivity)
    case setCursorLocation(CGPoint?)
    case setCursorReactionsEnabled(Bool)
    case setReduceMotion(Bool)
    case interaction(PetID, InteractionCommand)
    /// The connected screens (bounds for the out-of-bounds invariant).
    case screens([ScreenDescriptor])
    /// The complete set of surfaces; applied as a diff (moved surfaces keep attached pets).
    case surfaces([Surface])
}
