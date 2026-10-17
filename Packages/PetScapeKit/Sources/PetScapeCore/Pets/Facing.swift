/// Horizontal direction a pet or a piece of art faces.
public enum Facing: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case left
    case right

    public var opposite: Facing {
        switch self {
        case .left: .right
        case .right: .left
        }
    }
}
