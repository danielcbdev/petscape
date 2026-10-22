import AppKit
import PetScapeCore

/// Turns system notifications into suspension reasons (macos-integration.md#energy-and-system-events):
/// sleep/wake, display sleep, fast user switching and screen lock. Overlay occlusion is reported by the
/// overlay windows themselves; full-screen Spaces by `FullScreenSpaceDetector`. No permission needed
/// (PoC S6, S7).
public final class SystemEventsMonitor {
    /// A notification and the reason it starts (`true`) or ends (`false`).
    struct Mapping {
        var name: Notification.Name
        var reason: SuspensionReason
        var isActive: Bool
    }

    nonisolated static let workspaceMappings: [Mapping] = [
        Mapping(name: NSWorkspace.willSleepNotification, reason: .systemSleep, isActive: true),
        Mapping(name: NSWorkspace.didWakeNotification, reason: .systemSleep, isActive: false),
        Mapping(name: NSWorkspace.screensDidSleepNotification, reason: .displaySleep, isActive: true),
        Mapping(name: NSWorkspace.screensDidWakeNotification, reason: .displaySleep, isActive: false),
        Mapping(name: NSWorkspace.sessionDidResignActiveNotification, reason: .sessionInactive, isActive: true),
        Mapping(name: NSWorkspace.sessionDidBecomeActiveNotification, reason: .sessionInactive, isActive: false),
    ]

    /// Distributed notifications posted by loginwindow (validated in PoC S6/S7).
    nonisolated static let lockMappings: [Mapping] = [
        Mapping(name: Notification.Name("com.apple.screenIsLocked"), reason: .screenLocked, isActive: true),
        Mapping(name: Notification.Name("com.apple.screenIsUnlocked"), reason: .screenLocked, isActive: false),
    ]

    private let workspaceCenter: NotificationCenter
    private let distributedCenter: NotificationCenter
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    /// `distributedCenter` is `DistributedNotificationCenter.default()` in the app; tests pass a local center.
    public init(
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        distributedCenter: NotificationCenter = DistributedNotificationCenter.default()
    ) {
        self.workspaceCenter = workspaceCenter
        self.distributedCenter = distributedCenter
    }

    public var isStarted: Bool { !observers.isEmpty }

    /// Calls `onChange(reason, isActive)` for every mapped notification, on the main actor.
    public func start(
        onChange: @escaping @MainActor (SuspensionReason, Bool) -> Void,
        onReduceMotionChange: (@MainActor (Bool) -> Void)? = nil
    ) {
        guard observers.isEmpty else { return }
        onReduceMotionChange?(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        let sources = [(workspaceCenter, Self.workspaceMappings), (distributedCenter, Self.lockMappings)]
        for (center, mappings) in sources {
            for mapping in mappings {
                let token = center.addObserver(forName: mapping.name, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated {
                        Log.app.info(
                            "System event \(mapping.name.rawValue, privacy: .public) → \(String(describing: mapping.reason), privacy: .public) \(mapping.isActive ? "on" : "off", privacy: .public)"
                        )
                        onChange(mapping.reason, mapping.isActive)
                    }
                }
                observers.append((center, token))
            }
        }
        if let onReduceMotionChange {
            let token = workspaceCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    onReduceMotionChange(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                }
            }
            observers.append((workspaceCenter, token))
        }
    }

    /// Removes every observer (FR-13).
    public func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }
}
