/// MVP pet state machine (state-machines.md#mvp-pet-state-machine-m5m6):
///
/// ```
/// spawning ──placed──▶ walking ──edgeReached──▶ turning ──turnHold elapsed (facing flipped)──▶ walking
/// walking / turning ──surfaceLost / outOfBounds / invalidNumbers──▶ recovering ──next step──▶ spawning
/// ```
///
/// | State | Clip | Motion | Interrupt threshold | Duration |
/// |---|---|---|---|---|
/// | spawning | walk (frame 0) | none | 90 | 1 step once placed |
/// | walking | walk (loop) | along the surface at `nominalSpeed × speedScale`, direction = `facing` | 80 | until an edge |
/// | turning | walk (held on its current frame) | none | 90 | `turnHold`, then flip `facing` |
/// | recovering | — | none | — | 1 step |
public enum PetState: Equatable, Sendable {
    case spawning
    case walking
    case turning(to: Facing)
    case recovering(RecoveryReason)

    public var kind: PetStateKind {
        switch self {
        case .spawning: .spawning
        case .walking: .walking
        case .turning: .turning
        case .recovering: .recovering
        }
    }

    /// Minimum event priority that may interrupt the state (state-machines.md#event-priorities).
    public var interruptThreshold: Int {
        switch self {
        case .walking: 80
        case .spawning, .turning: 90
        case .recovering: Int.max
        }
    }
}

/// Payload-free state name, for events, logs and tests.
public enum PetStateKind: String, Sendable {
    case spawning
    case walking
    case turning
    case recovering
}

/// Why a pet had to be recovered (pet-engine.md#invariants-and-recovery).
public enum RecoveryReason: String, Sendable {
    /// The surface it stood on was removed.
    case surfaceLost
    /// Its contact point left every screen (plus margin).
    case outOfBounds
    /// Its position became NaN or infinite.
    case invalidNumbers
}
