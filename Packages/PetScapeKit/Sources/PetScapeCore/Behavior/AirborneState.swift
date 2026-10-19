/// Physical flight phases. Animation is a presentation of these states, never their authority.
public enum AirborneState: Equatable, Sendable {
    case falling
    case rising
}
