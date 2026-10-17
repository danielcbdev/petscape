import Foundation

/// "Call me once per display frame" (ADR-0013 as amended by ADR-0015). Paused = no callbacks, no wakeups.
public protocol FrameDriver: AnyObject {
    /// Called on the main actor with the frame's timestamp (system uptime, seconds).
    var onFrame: ((_ timestamp: TimeInterval) -> Void)? { get set }
    var isPaused: Bool { get set }
    /// Stops for good and releases the underlying display link.
    func invalidate()
}
