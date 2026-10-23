import AppKit
import PetScapeCore

/// Throttles CG snapshots and scopes AX observation to the frontmost application.
/// The owner controls start/stop from feature opt-in and RunStatus transitions.
@MainActor
public final class CompositeWindowTracker {
    public private(set) var isAvailable = false
    public var onChange: (([TrackedWindow]) -> Void)?
    public var onPermissionRevoked: (() -> Void)?

    private let snapshotSource: CGWindowSnapshotSource
    private let permission: any AccessibilityPermissionProviding
    private var converter: CoordinateConverter?
    private var timer: Timer?
    private var activationObserver: (any NSObjectProtocol)?
    private var accessibilityObserver: AccessibilityWindowObserver?
    private var lastSnapshotTime = -Double.infinity

    public convenience init() {
        self.init(snapshotSource: CGWindowSnapshotSource(), permission: AccessibilityPermission())
    }

    init(
        snapshotSource: CGWindowSnapshotSource = CGWindowSnapshotSource(),
        permission: any AccessibilityPermissionProviding = AccessibilityPermission()
    ) {
        self.snapshotSource = snapshotSource
        self.permission = permission
    }

    public func start(converter: CoordinateConverter) {
        guard timer == nil, permission.isTrusted else { return }
        self.converter = converter
        isAvailable = true
        observeFrontmostApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.permission.isTrusted else {
                    self.stop()
                    self.onPermissionRevoked?()
                    return
                }
                self.observeFrontmostApplication()
                self.refresh()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh(force: true)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        accessibilityObserver?.stop()
        accessibilityObserver = nil
        converter = nil
        isAvailable = false
        lastSnapshotTime = -Double.infinity
        onChange?([])
    }

    public func updateScreens(_ converter: CoordinateConverter) {
        guard timer != nil else { return }
        guard permission.isTrusted else {
            stop()
            onPermissionRevoked?()
            return
        }
        self.converter = converter
        refresh(force: true)
    }

    private func observeFrontmostApplication() {
        accessibilityObserver?.stop()
        accessibilityObserver = nil
        guard permission.isTrusted,
            let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            processID != Int32(ProcessInfo.processInfo.processIdentifier)
        else { return }
        let observer = AccessibilityWindowObserver(
            processID: processID,
            onChange: { [weak self] in self?.refresh() },
            onPermissionRevoked: { [weak self] in
                self?.stop()
                self?.onPermissionRevoked?()
            })
        if observer.start() { accessibilityObserver = observer }
    }

    private func refresh(force: Bool = false) {
        guard timer != nil, let converter else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastSnapshotTime >= 0.5 else { return }
        lastSnapshotTime = now
        onChange?(snapshotSource.snapshot(converter: converter))
    }

}
