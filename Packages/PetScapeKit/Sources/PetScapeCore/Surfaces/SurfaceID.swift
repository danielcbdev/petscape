/// Stable identity of a surface across updates (surface-detection.md): a moved surface keeps its ID so
/// attached pets ride it; a new ID is a different surface.
public struct SurfaceID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// The bottom edge of a screen: `screen:<id>:bottom`.
    public static func screenBottom(of screen: ScreenID) -> SurfaceID {
        SurfaceID("screen:\(screen):bottom")
    }

    public var description: String { rawValue }
}
