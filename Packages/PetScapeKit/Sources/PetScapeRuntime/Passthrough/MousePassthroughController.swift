import Foundation
import PetScapeCore
import PetScapePlatform

/// Decides when the overlay accepts the mouse (strategy C, ADR-0003, macos-integration.md):
/// pass-through by default, interactive only while the cursor is over a pet, and kept interactive for
/// the whole drag that started on the pet.
///
/// ```
/// passThrough ──over pet, no button held──▶ interactive ──mouse down──▶ dragging
///      ▲                                       │  ▲                          │
///      └──────────── left the pet ─────────────┘  └── mouse up over the pet ─┤
///      └──────────────────────── mouse up elsewhere / button released ───────┘
/// ```
public final class MousePassthroughController {
    public enum State: Equatable, Sendable {
        case passThrough
        case interactive
        case dragging
    }

    /// Replaceable so M5 can swap the DEBUG rectangle for the real alpha-mask hit tester.
    public var hitTester: any PetHitTesting
    public private(set) var state: State = .passThrough
    public var isEnabled = true {
        didSet {
            if !isEnabled { reset() }
        }
    }

    /// Applies `ignoresMouseEvents` to the overlays; called only on changes.
    private let applyIgnoresMouseEvents: (Bool) -> Void
    private let uptime: () -> TimeInterval
    private var lastSampleTimestamp: TimeInterval?

    public init(
        hitTester: any PetHitTesting,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        applyIgnoresMouseEvents: @escaping (Bool) -> Void
    ) {
        self.hitTester = hitTester
        self.uptime = uptime
        self.applyIgnoresMouseEvents = applyIgnoresMouseEvents
    }

    public var isInteractive: Bool { state != .passThrough }

    /// A cursor sample from the frame loop or the idle mouse monitor.
    public func update(with sample: CursorSample) {
        guard isEnabled else { return }
        Signposts.measure(Signposts.Interval.passthroughUpdate) {
            defer { lastSampleTimestamp = sample.timestamp }
            switch state {
            case .passThrough:
                // A button already held means a drag in another app passes over the pet: never capture it.
                if !sample.isButtonDown, hitTester.containsPet(at: sample.location) {
                    transition(to: .interactive, reason: "cursor entered the pet", sample: sample)
                }
            case .interactive:
                if !hitTester.containsPet(at: sample.location) {
                    transition(to: .passThrough, reason: "cursor left the pet", sample: sample)
                }
            case .dragging:
                // Safety net: a lost mouse-up (window ordered out, app switch) must not leave the overlay
                // capturing clicks.
                if !sample.isButtonDown {
                    finishDrag(at: sample.location, reason: "button released without mouse-up", sample: sample)
                }
            }
        }
    }

    /// Mouse down delivered to the overlay (only possible while interactive).
    public func mouseDown(at location: CGPoint) {
        guard isEnabled else { return }
        guard state == .interactive else { return }
        transition(to: .dragging, reason: "mouse down on the pet", sample: nil)
    }

    public func mouseUp(at location: CGPoint) {
        guard isEnabled else { return }
        guard state == .dragging else { return }
        finishDrag(at: location, reason: "mouse up", sample: nil)
    }

    /// Back to pass-through regardless of state (overlay hidden, suspended, screens changed).
    public func reset() {
        lastSampleTimestamp = nil
        guard state != .passThrough else { return }
        transition(to: .passThrough, reason: "reset", sample: nil)
    }

    private func finishDrag(at location: CGPoint, reason: String, sample: CursorSample?) {
        let next: State = hitTester.containsPet(at: location) ? .interactive : .passThrough
        transition(to: next, reason: reason, sample: sample)
    }

    private func transition(to next: State, reason: String, sample: CursorSample?) {
        let wasInteractive = isInteractive
        state = next
        guard isInteractive != wasInteractive else { return }
        applyIgnoresMouseEvents(!isInteractive)
        logToggle(reason: reason, sample: sample)
    }

    /// DEBUG evidence for AC-M3-04: the toggle happens in the same callback as the first sample over/off
    /// the pet; the gap since the previous sample bounds when the cursor actually crossed the edge.
    private func logToggle(reason: String, sample: CursorSample?) {
        #if DEBUG
            let mode = isInteractive ? "interactive" : "pass-through"
            if let sample {
                let sampleToToggle = (uptime() - sample.timestamp) * 1000
                let previousGap = lastSampleTimestamp.map { (sample.timestamp - $0) * 1000 } ?? -1
                Log.overlay.debug(
                    "Pass-through → \(mode, privacy: .public) (\(reason, privacy: .public)); sample→toggle \(sampleToToggle, format: .fixed(precision: 2), privacy: .public) ms, previous sample \(previousGap, format: .fixed(precision: 2), privacy: .public) ms earlier"
                )
            } else {
                Log.overlay.debug("Pass-through → \(mode, privacy: .public) (\(reason, privacy: .public))")
            }
        #endif
    }
}
