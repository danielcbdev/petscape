/// A system condition that stops the simulation without the user asking (data-flow.md#run-state).
/// Never persisted.
public enum SuspensionReason: CaseIterable, Hashable, Sendable {
    /// `NSWorkspace.willSleep` … `didWake`.
    case systemSleep
    /// `NSWorkspace.screensDidSleep` … `screensDidWake`.
    case displaySleep
    /// Fast user switching: `sessionDidResignActive` … `sessionDidBecomeActive`.
    case sessionInactive
    /// `com.apple.screenIsLocked` … `screenIsUnlocked`.
    case screenLocked
    /// The active Space shows a full-screen app (`FullScreenSpaceRule`); the overlay must not cover it.
    case fullScreenSpace
    /// No screen is available to host an overlay.
    case noScreens
    /// The overlay is ordered in but not visible to the user (occlusion state).
    case overlayOccluded

    /// Whether the overlay must be ordered out while this reason holds. Occlusion is the exception: it
    /// is a *consequence* of the overlay's visibility, so ordering out because of it would never end.
    public var hidesOverlay: Bool {
        switch self {
        case .systemSleep, .displaySleep, .sessionInactive, .screenLocked, .fullScreenSpace, .noScreens: true
        case .overlayOccluded: false
        }
    }
}
