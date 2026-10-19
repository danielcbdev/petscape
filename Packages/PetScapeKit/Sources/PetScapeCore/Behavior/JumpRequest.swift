import CoreGraphics

/// A movement request, not a trajectory or another source of position truth.
public struct JumpRequest: Equatable, Sendable {
    public enum Target: Equatable, Sendable {
        case vertical
        case horizontal(Double)
        case surface(SurfaceID, x: CGFloat)
    }
    public let target: Target
    public let returnActivity: ResumeActivity

    public init(target: Target = .vertical, returnActivity: ResumeActivity = .walking) {
        self.target = target
        self.returnActivity = returnActivity
    }
}

public enum JumpRejection: String, Equatable, Sendable {
    case unknownPet, busy, cooldown, invalidTarget, unreachable
}
