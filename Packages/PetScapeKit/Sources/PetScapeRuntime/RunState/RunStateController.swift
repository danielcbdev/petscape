import PetScapeCore

/// Combines user intent (pause/hide) with system conditions (sleep, lock, display sleep, session,
/// occlusion, full-screen Space, no screens) into a `RunStatus` (data-flow.md#run-state). Reports only
/// changes. The policy itself is `RunStatus.resolve` (Core, unit-tested for every combination).
public final class RunStateController {
    public private(set) var intent: UserIntent
    public private(set) var reasons: Set<SuspensionReason> = []
    public private(set) var status: RunStatus
    /// Called after every change of `status`.
    public var onChange: ((RunStatus) -> Void)?

    public init(intent: UserIntent = UserIntent()) {
        self.intent = intent
        status = RunStatus.resolve(intent: intent, reasons: [])
    }

    public func setPaused(_ paused: Bool) {
        intent.isPaused = paused
        recompute()
    }

    public func setHidden(_ hidden: Bool) {
        intent.isHidden = hidden
        recompute()
    }

    public func setCondition(_ reason: SuspensionReason, isActive: Bool) {
        if isActive {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        recompute()
    }

    private func recompute() {
        let next = RunStatus.resolve(intent: intent, reasons: reasons)
        guard next != status else { return }
        status = next
        Signposts.event(Signposts.Event.runStateChanged)
        Log.app.info(
            "Run state \(String(describing: next.state), privacy: .public): overlay \(next.isOverlayVisible ? "visible" : "hidden", privacy: .public), frames \(next.isFrameDriverRunning ? "on" : "off", privacy: .public), idle cursor monitor \(next.isIdleCursorMonitorNeeded ? "on" : "off", privacy: .public)"
        )
        onChange?(next)
    }
}
