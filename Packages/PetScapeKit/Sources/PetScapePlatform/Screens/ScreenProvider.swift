import AppKit
import PetScapeCore

/// Reads `NSScreen` into `ScreenDescriptor` values and reports configuration changes
/// (resolution, scaling, arrangement, connect/disconnect, Dock size/position) — coordinate-system.md.
public final class ScreenProvider {
    /// What `NSScreen` says about one display; separated from `NSScreen` so the mapping is testable.
    struct RawScreen: Equatable {
        var displayID: UInt32?
        var frame: CGRect
        var visibleFrame: CGRect
        var backingScale: CGFloat
    }

    private let notificationCenter: NotificationCenter
    private var observer: (any NSObjectProtocol)?

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// Current screens; the first one is the primary screen (global origin), as in `NSScreen.screens`.
    public func currentScreens() -> [ScreenDescriptor] {
        Self.descriptors(
            from: NSScreen.screens.map { screen in
                RawScreen(
                    displayID: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                        .uint32Value,
                    frame: screen.frame, visibleFrame: screen.visibleFrame, backingScale: screen.backingScaleFactor)
            })
    }

    /// Calls `onChange` with fresh descriptors after every `didChangeScreenParametersNotification`.
    public func start(onChange: @escaping @MainActor ([ScreenDescriptor]) -> Void) {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let screens = self.currentScreens()
                Log.overlay.notice("Screen parameters changed: \(Self.summary(of: screens), privacy: .public)")
                onChange(screens)
            }
        }
    }

    /// Removes the observer (FR-13). Call before releasing the provider.
    public func stop() {
        if let observer { notificationCenter.removeObserver(observer) }
        observer = nil
    }

    /// Maps raw screens to descriptors: index 0 is primary; screens without a display ID are skipped
    /// (they cannot be identified across changes).
    nonisolated static func descriptors(from rawScreens: [RawScreen]) -> [ScreenDescriptor] {
        rawScreens.enumerated().compactMap { index, raw in
            guard let displayID = raw.displayID else { return nil }
            return ScreenDescriptor(
                id: ScreenID(displayID), frame: raw.frame, visibleFrame: raw.visibleFrame,
                backingScale: Double(raw.backingScale), isPrimary: index == 0)
        }
    }

    /// One line per screen for the log (no sensitive data: geometry only).
    public nonisolated static func summary(of screens: [ScreenDescriptor]) -> String {
        guard !screens.isEmpty else { return "no screens" }
        return screens.map { screen in
            "[id=\(screen.id) frame=\(screen.frame) visibleFrame=\(screen.visibleFrame) "
                + "scale=\(screen.backingScale)\(screen.isPrimary ? " primary" : "")]"
        }.joined(separator: " ")
    }
}
