/// What a surface is (surface-detection.md). Walls and window tops arrive with M11 and M12–M13.
public enum SurfaceKind: String, Sendable {
    /// The top of the Dock shelf (M6).
    case dockTop
    /// The bottom edge of a screen: the floor of last resort, and the temporary walkway in M5.
    case screenBottom
}
