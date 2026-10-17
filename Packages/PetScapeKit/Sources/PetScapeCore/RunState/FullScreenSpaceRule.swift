/// One on-screen window as listed by `CGWindowListCopyWindowInfo`, reduced to what the full-screen rule
/// needs. Owner process name and layer only — never titles or contents (AGENTS.md §11).
public struct WindowListEntry: Equatable, Sendable {
    public var ownerName: String
    public var layer: Int

    public init(ownerName: String, layer: Int) {
        self.ownerName = ownerName
        self.layer = layer
    }
}

/// What one read of the on-screen window list says about the Dock.
public enum DockWindowReading: Equatable, Sendable {
    case present
    case absent
    /// The window list could not be read (API returned nothing); never treated as evidence.
    case unavailable
}

/// Kind of the active Space, as far as the overlay is concerned.
public enum SpaceKind: Equatable, Sendable {
    case desktop
    case fullScreen
}

/// Full-screen Space rule (ADR-0003, PoC S5, task T3.10): the collection behavior does not keep the
/// overlay out of full-screen app Spaces, but such Spaces have **no on-screen window owned by the Dock at
/// the Dock level** (desktops always have one, also with Dock auto-hide). After `activeSpaceDidChange`
/// the list is read twice, `Timing.confirmationDelay` apart, once the transition settled; only two
/// agreeing reads change the decision.
public enum FullScreenSpaceRule {
    /// Process name of the Dock in the window list.
    public static let dockOwnerName = "Dock"

    /// Delays validated in the PoC (overlay hidden ~1 s after entering a full-screen Space).
    public enum Timing {
        /// Wait after `activeSpaceDidChange` before the first read (the transition is still animating).
        public static let settleDelay: Duration = .milliseconds(600)
        /// Wait between the first and the second read.
        public static let confirmationDelay: Duration = .milliseconds(400)
    }

    /// `windows` are the on-screen windows (`optionOnScreenOnly`); `nil` when the list was unavailable.
    public static func reading(of windows: [WindowListEntry]?, dockLevel: Int) -> DockWindowReading {
        guard let windows, !windows.isEmpty else { return .unavailable }
        let hasDockWindow = windows.contains { $0.ownerName == dockOwnerName && $0.layer == dockLevel }
        return hasDockWindow ? .present : .absent
    }

    /// The Space kind when both reads agree, `nil` when they disagree or either is unavailable
    /// (inconclusive: keep the current decision).
    public static func spaceKind(first: DockWindowReading, second: DockWindowReading) -> SpaceKind? {
        switch (first, second) {
        case (.present, .present): .desktop
        case (.absent, .absent): .fullScreen
        case (.present, _), (.absent, _), (.unavailable, _): nil
        }
    }
}
