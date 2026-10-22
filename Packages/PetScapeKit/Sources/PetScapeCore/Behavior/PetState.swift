/// Single pet execution hierarchy (state-machines.md). RunState independently gates simulation time.
public enum PetState: Equatable, Sendable {
    case spawning
    case grounded(GroundedState)
    case airborne(AirborneState)
    case held
    case recovering(RecoveryReason)

    /// Source-compatible construction of the existing walking/turning states.
    public static var walking: Self { .grounded(.walking) }
    public static func turning(to facing: Facing) -> Self { .grounded(.turning(to: facing)) }

    public var kind: PetStateKind {
        switch self {
        case .spawning: .spawning
        case .grounded(.walking): .walking
        case .grounded(.turning): .turning
        case .grounded(.landing): .landing
        case .grounded(.idle): .idle
        case .grounded(.preparingJump): .preparingJump
        case .grounded(.sittingDown): .sittingDown
        case .grounded(.sitting): .sitting
        case .grounded(.standingUp): .standingUp
        case .grounded(.lyingDown): .lyingDown
        case .grounded(.sleeping): .sleeping
        case .grounded(.wakingUp): .wakingUp
        case .grounded(.stretching): .stretching
        case .grounded(.observing): .observing
        case .grounded(.reactingToCursor): .reactingToCursor
        case .grounded(.reactingToClick): .reactingToClick
        case .airborne(.falling): .falling
        case .airborne(.rising): .rising
        case .recovering: .recovering
        case .held: .held
        }
    }

    public var interruptThreshold: Int {
        switch self {
        case .grounded(.walking): 80
        case .grounded(.idle): 10
        case .recovering: Int.max
        case .held: Int.max
        case .spawning, .grounded, .airborne: 90
        }
    }
}

public enum PetStateKind: String, Sendable {
    case spawning, walking, turning, falling, landing, recovering, idle, preparingJump, rising
    case sittingDown, sitting, standingUp, lyingDown, sleeping, wakingUp, stretching, observing
    case reactingToCursor, reactingToClick, held
}

public enum RecoveryReason: String, Sendable {
    /// Retained for compatibility; ordinary support loss now falls instead of respawning.
    case surfaceLost
    case outOfBounds
    case invalidNumbers
    case invalidContact
    case airborneTimeout
}
