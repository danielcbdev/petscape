import ApplicationServices
import CoreFoundation

/// Observes only the focused window of one process. AX values and names never leave this adapter.
@MainActor
public final class AccessibilityWindowObserver {
    private let processID: Int32
    private let onChange: () -> Void
    private let onPermissionRevoked: () -> Void
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var focusedWindow: AXUIElement?

    public init(processID: Int32, onChange: @escaping () -> Void, onPermissionRevoked: @escaping () -> Void) {
        self.processID = processID
        self.onChange = onChange
        self.onPermissionRevoked = onPermissionRevoked
    }

    @discardableResult
    public func start() -> Bool {
        guard observer == nil, AXIsProcessTrusted() else { return false }
        var created: AXObserver?
        guard
            AXObserverCreate(
                processID,
                { _, _, notification, refcon in
                    guard let refcon else { return }
                    MainActor.assumeIsolated {
                        Unmanaged<AccessibilityWindowObserver>.fromOpaque(refcon).takeUnretainedValue().received(
                            notification)
                    }
                }, &created) == .success,
            let created
        else { return false }
        observer = created
        application = AXUIElementCreateApplication(processID)
        guard let application else { stop(); return false }
        let timeoutResult = AXUIElementSetMessagingTimeout(application, 0.25)
        if timeoutResult.rawValue == -25211 { handle(timeoutResult); stop(); return false }
        let result = AXObserverAddNotification(
            created, application, kAXFocusedWindowChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        guard result == .success || result == .notificationAlreadyRegistered else {
            handle(result)
            stop()
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observeFocusedWindow()
        return true
    }

    public func stop() {
        if let observer {
            if let application {
                AXObserverRemoveNotification(observer, application, kAXFocusedWindowChangedNotification as CFString)
            }
            if let focusedWindow {
                for notification in [
                    kAXWindowMovedNotification, kAXWindowResizedNotification, kAXUIElementDestroyedNotification,
                ] {
                    AXObserverRemoveNotification(observer, focusedWindow, notification as CFString)
                }
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        application = nil
        focusedWindow = nil
    }

    fileprivate func received(_ notification: CFString) {
        if notification as String == kAXFocusedWindowChangedNotification as String { observeFocusedWindow() }
        onChange()
    }

    private func observeFocusedWindow() {
        guard let observer, let application else { return }
        if let focusedWindow {
            for notification in [
                kAXWindowMovedNotification, kAXWindowResizedNotification, kAXUIElementDestroyedNotification,
            ] {
                AXObserverRemoveNotification(observer, focusedWindow, notification as CFString)
            }
        }
        focusedWindow = nil
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            handle(result)
            return
        }
        let window = unsafeDowncast(value, to: AXUIElement.self)
        focusedWindow = window
        let timeoutResult = AXUIElementSetMessagingTimeout(window, 0.25)
        if timeoutResult.rawValue == -25211 { handle(timeoutResult); return }
        for notification in [
            kAXWindowMovedNotification, kAXWindowResizedNotification, kAXUIElementDestroyedNotification,
        ] {
            let addResult = AXObserverAddNotification(
                observer, window, notification as CFString, Unmanaged.passUnretained(self).toOpaque())
            if addResult.rawValue == -25211 { handle(addResult); return }
        }
    }

    private func handle(_ error: AXError) {
        if error.rawValue == -25211 {
            stop()
            onPermissionRevoked()
        }
    }

}
