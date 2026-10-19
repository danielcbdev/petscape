/// Explicit grounded intent to restore after a physical jump; autonomous selection is deferred to M9.
public enum ResumeActivity: Equatable, Sendable {
    case walking
    case idle
}
