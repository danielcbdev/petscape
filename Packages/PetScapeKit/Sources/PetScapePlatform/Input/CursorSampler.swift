import AppKit
import PetScapeCore

/// Cursor state at one instant, canonical global points.
public struct CursorSample: Equatable, Sendable {
    public var location: CGPoint
    /// Any mouse button held (a drag may be in progress in another app).
    public var isButtonDown: Bool
    /// System uptime of the sample (same time base as `NSEvent.timestamp`).
    public var timestamp: TimeInterval

    public init(location: CGPoint, isButtonDown: Bool, timestamp: TimeInterval) {
        self.location = location
        self.isButtonDown = isButtonDown
        self.timestamp = timestamp
    }
}

/// Installs and removes the global mouse-moved monitor; a seam so the sampler's lifecycle is testable.
public protocol GlobalMouseMonitoring {
    /// Installs a monitor for mouse-moved events delivered to *other* apps. Returns `nil` if AppKit refused.
    func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any?
    func removeMonitor(_ monitor: Any)
}

/// `NSEvent` global monitor. Mouse events need no permission (PoC E2: delivered without Accessibility).
public struct NSEventGlobalMouseMonitoring: GlobalMouseMonitoring {
    public init() {}

    public func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
            // Global monitor handlers run on the main thread.
            let sample = CursorSample(
                location: NSEvent.mouseLocation, isButtonDown: NSEvent.pressedMouseButtons != 0,
                timestamp: event.timestamp)
            MainActor.assumeIsolated { handler(sample) }
        }
    }

    public func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

/// Cursor source for pass-through (macos-integration.md#click-through-strategies):
/// - `sample()` once per frame while the simulation runs (no permission, no wakeups of its own);
/// - a global mouse-moved monitor **only while paused and visible** (no frames then), removed otherwise.
public final class CursorSampler {
    private let monitoring: any GlobalMouseMonitoring
    private var monitor: Any?

    public init(monitoring: any GlobalMouseMonitoring = NSEventGlobalMouseMonitoring()) {
        self.monitoring = monitoring
    }

    public var isMonitoring: Bool { monitor != nil }

    public func sample() -> CursorSample {
        CursorSample(
            location: NSEvent.mouseLocation, isButtonDown: NSEvent.pressedMouseButtons != 0,
            timestamp: ProcessInfo.processInfo.systemUptime)
    }

    /// Installs the global monitor once; further calls while monitoring are ignored.
    public func startMonitoring(onMove: @escaping @MainActor (CursorSample) -> Void) {
        guard monitor == nil else { return }
        monitor = monitoring.addMouseMovedMonitor(onMove)
        if monitor == nil {
            Log.overlay.error("Global mouse-moved monitor could not be installed")
        } else {
            Log.overlay.info("Global mouse-moved monitor installed")
        }
    }

    public func stopMonitoring() {
        guard let monitor else { return }
        monitoring.removeMonitor(monitor)
        self.monitor = nil
        Log.overlay.info("Global mouse-moved monitor removed")
    }
}
