/// What a surface is (surface-detection.md).
public enum SurfaceKind: String, Sendable {
    /// The top of the Dock shelf (M6).
    case dockTop
    /// The bottom edge of a screen: the floor of last resort, and the temporary walkway in M5.
    case screenBottom
    /// Left vertical edge of a screen (M11).
    case screenLeft
    /// Right vertical edge of a screen (M11).
    case screenRight
}

/// Screen edge a climbing pet is attached to.
public enum WallSide: String, Sendable {
    case left
    case right
}
