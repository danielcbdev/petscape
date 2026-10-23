/// Stable identity of a surface across updates (surface-detection.md): a moved surface keeps its ID so
/// attached pets ride it; a new ID is a different surface.
public struct SurfaceID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// The top of the Dock shelf (one Dock per session; it keeps this ID when it is resized or moves to
    /// another screen, so the pet rides it).
    public static let dock = SurfaceID("dock")

    /// The bottom edge of a screen: `screen:<id>:bottom`.
    public static func screenBottom(of screen: ScreenID) -> SurfaceID {
        SurfaceID("screen:\(screen):bottom")
    }

    public static func screenLeft(of screen: ScreenID) -> SurfaceID {
        SurfaceID("screen:\(screen):left")
    }

    public static func screenRight(of screen: ScreenID) -> SurfaceID {
        SurfaceID("screen:\(screen):right")
    }

    public var description: String { rawValue }
}
