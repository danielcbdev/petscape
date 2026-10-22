import AppKit
import PetScapeCore

/// Cursor state at one instant, canonical global points.
public struct CursorSample: Equatable, Sendable {
    public var location: CGPoint
    /// Any mouse button held (a drag may be in progress in another app).
    public var isButtonDown: Bool
    /// The primary mouse button, distinguished from secondary-button state for lost-up recovery.
    public var isPrimaryButtonDown: Bool
    /// System uptime of the sample (same time base as `NSEvent.timestamp`).
    public var timestamp: TimeInterval

    public init(
        location: CGPoint, isButtonDown: Bool, timestamp: TimeInterval,
        isPrimaryButtonDown: Bool = false
    ) {
        self.location = location
        self.isButtonDown = isButtonDown
        self.isPrimaryButtonDown = isPrimaryButtonDown
        self.timestamp = timestamp
    }
}

/// Installs and removes the global mouse-moved monitor; a seam so the sampler's lifecycle is testable.
public protocol GlobalMouseMonitoring {
    /// Installs a monitor for mouse-moved events delivered to *other* apps. Returns `nil` if AppKit refused.
    func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any?
    func removeMonitor(_ monitor: Any)
}

public protocol LocalMouseMonitoring {
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
                timestamp: event.timestamp,
                isPrimaryButtonDown: NSEvent.pressedMouseButtons & 1 != 0)
            MainActor.assumeIsolated { handler(sample) }
        }
    }

    public func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

public struct NSEventLocalMouseMonitoring: LocalMouseMonitoring {
    public init() {}

    public func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            let origin = event.window?.frame.origin ?? .zero
            let sample = CursorSample(
                location: CGPoint(
                    x: origin.x + event.locationInWindow.x,
                    y: origin.y + event.locationInWindow.y),
                isButtonDown: NSEvent.pressedMouseButtons != 0,
                timestamp: event.timestamp,
                isPrimaryButtonDown: NSEvent.pressedMouseButtons & 1 != 0)
            MainActor.assumeIsolated { handler(sample) }
            return event
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
    private let localMonitoring: any LocalMouseMonitoring
    private var monitor: Any?
    private var localMonitor: Any?
    private var generation: UInt64 = 0

    public init(
        monitoring: any GlobalMouseMonitoring = NSEventGlobalMouseMonitoring(),
        localMonitoring: any LocalMouseMonitoring = NSEventLocalMouseMonitoring()
    ) {
        self.monitoring = monitoring
        self.localMonitoring = localMonitoring
    }

    public var isMonitoring: Bool { monitor != nil || localMonitor != nil }

    public func sample() -> CursorSample {
        CursorSample(
            location: NSEvent.mouseLocation, isButtonDown: NSEvent.pressedMouseButtons != 0,
            timestamp: ProcessInfo.processInfo.systemUptime,
            isPrimaryButtonDown: NSEvent.pressedMouseButtons & 1 != 0)
    }

    /// Installs the global monitor once; further calls while monitoring are ignored.
    public func startMonitoring(onMove: @escaping @MainActor (CursorSample) -> Void) {
        guard !isMonitoring else { return }
        generation &+= 1
        let activeGeneration = generation
        monitor = monitoring.addMouseMovedMonitor { [weak self] sample in
            guard self?.generation == activeGeneration else { return }
            onMove(sample)
        }
        localMonitor = localMonitoring.addMouseMovedMonitor { [weak self] sample in
            guard self?.generation == activeGeneration else { return }
            onMove(sample)
        }
        if monitor == nil && localMonitor == nil {
            Log.overlay.error("Global mouse-moved monitor could not be installed")
        }
        if monitor != nil { Log.overlay.info("Global mouse-moved monitor installed") }
        if localMonitor != nil { Log.overlay.info("Local mouse-moved monitor installed") }
    }

    public func stopMonitoring() {
        generation &+= 1
        if let monitor { monitoring.removeMonitor(monitor) }
        if let localMonitor { localMonitoring.removeMonitor(localMonitor) }
        self.monitor = nil
        self.localMonitor = nil
    }
}
