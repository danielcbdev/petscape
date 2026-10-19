/// Physical ground phases in the existing PetState hierarchy; operational run state stays separate.
public enum GroundedState: Equatable, Sendable {
    case walking
    case turning(to: Facing)
    case landing
    case idle
    case sittingDown, sitting, standingUp, lyingDown, sleeping, wakingUp, stretching, observing
    case preparingJump
}
