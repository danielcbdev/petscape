/// App-level run state (data-flow.md#run-state). `Loading`/`Degraded` arrive with character loading (M5).
public enum RunState: Hashable, Sendable {
    /// Simulation and rendering run; the frame driver is the only thing ticking.
    case running
    /// User pause: sprites visible, frame driver stopped.
    case paused
    /// User hide: overlays ordered out, frame driver stopped.
    case hidden
    /// System-driven stop; only ever replaces `running` (a paused or hidden pet stays so through sleep).
    case suspended(Set<SuspensionReason>)
}

/// Everything the runtime derives from user intent × system conditions. Pure value; computed by
/// `RunStatus.resolve(intent:reasons:)` so every combination is unit-testable.
public struct RunStatus: Hashable, Sendable {
    public var state: RunState
    /// Overlay panels ordered in.
    public var isOverlayVisible: Bool
    /// Display-link frame driver unpaused (simulation stepping, cursor sampled per frame).
    public var isFrameDriverRunning: Bool
    /// Global mouse-moved monitor installed so pass-through still works without frames: only while the
    /// pet is on screen and no frames run (paused) — never while hidden, suspended for hiding reasons or
    /// occluded (macos-integration.md#click-through-strategies).
    public var isIdleCursorMonitorNeeded: Bool

    public init(state: RunState, isOverlayVisible: Bool, isFrameDriverRunning: Bool, isIdleCursorMonitorNeeded: Bool) {
        self.state = state
        self.isOverlayVisible = isOverlayVisible
        self.isFrameDriverRunning = isFrameDriverRunning
        self.isIdleCursorMonitorNeeded = isIdleCursorMonitorNeeded
    }

    /// Precedence: hidden > paused > suspended > running. Visibility is decided separately so that a
    /// paused pet still disappears in a full-screen Space or while the screen is locked.
    public static func resolve(intent: UserIntent, reasons: Set<SuspensionReason>) -> RunStatus {
        let state: RunState =
            if intent.isHidden {
                .hidden
            } else if intent.isPaused {
                .paused
            } else if !reasons.isEmpty {
                .suspended(reasons)
            } else {
                .running
            }
        let isOverlayVisible = !intent.isHidden && !reasons.contains { $0.hidesOverlay }
        let isFrameDriverRunning = state == .running
        let isIdleCursorMonitorNeeded =
            isOverlayVisible && !isFrameDriverRunning && !reasons.contains(.overlayOccluded)
        return RunStatus(
            state: state, isOverlayVisible: isOverlayVisible, isFrameDriverRunning: isFrameDriverRunning,
            isIdleCursorMonitorNeeded: isIdleCursorMonitorNeeded)
    }
}
