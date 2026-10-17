import AppKit
import PetScapeCore

/// Platform side of the full-screen Space rule (`FullScreenSpaceRule`, ADR-0003, T3.10): after each
/// `activeSpaceDidChange` it reads the on-screen window list twice — once the transition settled and again
/// `confirmationDelay` later — and reports a change only when both reads agree.
///
/// Reads owner names and layers only (no titles, no contents); `CGWindowListCopyWindowInfo` needs no
/// permission for these fields (PoC S5).
public final class FullScreenSpaceDetector {
    public typealias WindowListReader = @MainActor () -> [WindowListEntry]?

    private let workspaceCenter: NotificationCenter
    private let readWindowList: WindowListReader
    private let settleDelay: Duration
    private let confirmationDelay: Duration
    private let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
    private var observer: (any NSObjectProtocol)?
    private var checkTask: Task<Void, Never>?
    private var onChange: (@MainActor (Bool) -> Void)?

    /// Current decision; starts as `.desktop` until two reads say otherwise.
    public private(set) var spaceKind: SpaceKind = .desktop

    public init(
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        settleDelay: Duration = FullScreenSpaceRule.Timing.settleDelay,
        confirmationDelay: Duration = FullScreenSpaceRule.Timing.confirmationDelay,
        readWindowList: @escaping WindowListReader = FullScreenSpaceDetector.onScreenWindows
    ) {
        self.workspaceCenter = workspaceCenter
        self.settleDelay = settleDelay
        self.confirmationDelay = confirmationDelay
        self.readWindowList = readWindowList
    }

    /// Observes Space changes and checks the current Space once right away (the app may be launched
    /// from a full-screen Space). `onChange(true)` = full-screen Space entered.
    public func start(onChange: @escaping @MainActor (Bool) -> Void) {
        guard observer == nil else { return }
        self.onChange = onChange
        observer = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck(after: self?.settleDelay ?? .zero) }
        }
        scheduleCheck(after: .zero)
    }

    /// Removes the observer and cancels a pending check (FR-13).
    public func stop() {
        if let observer { workspaceCenter.removeObserver(observer) }
        observer = nil
        checkTask?.cancel()
        checkTask = nil
        onChange = nil
    }

    /// A newer Space change supersedes a pending check.
    private func scheduleCheck(after delay: Duration) {
        checkTask?.cancel()
        checkTask = Task { [weak self, confirmationDelay] in
            do {
                try await Task.sleep(for: delay)
                guard let first = self?.read() else { return }
                try await Task.sleep(for: confirmationDelay)
                guard let self else { return }
                self.apply(first: first, second: self.read())
            } catch {
                // Cancelled by a newer Space change or by stop().
            }
        }
    }

    private func read() -> DockWindowReading {
        FullScreenSpaceRule.reading(of: readWindowList(), dockLevel: dockLevel)
    }

    private func apply(first: DockWindowReading, second: DockWindowReading) {
        guard let kind = FullScreenSpaceRule.spaceKind(first: first, second: second) else {
            Log.overlay.info(
                "Full-screen check inconclusive (\(String(describing: first), privacy: .public) → \(String(describing: second), privacy: .public)); keeping \(String(describing: self.spaceKind), privacy: .public)"
            )
            return
        }
        guard kind != spaceKind else { return }
        spaceKind = kind
        Log.overlay.notice(
            "\(kind == .fullScreen ? "Full-screen Space detected (no Dock window)" : "Desktop Space (Dock window present)", privacy: .public)"
        )
        onChange?(kind == .fullScreen)
    }

    /// On-screen windows reduced to owner name and layer; `nil` if the window server returned nothing.
    public static func onScreenWindows() -> [WindowListEntry]? {
        guard
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return nil }
        return windows.compactMap { window in
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                let layer = window[kCGWindowLayer as String] as? Int
            else { return nil }
            return WindowListEntry(ownerName: owner, layer: layer)
        }
    }
}
