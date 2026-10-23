import AppKit
import ApplicationServices
import Foundation

/// Explicit Accessibility consent boundary. No method is called until the user enables the feature.
@MainActor
public protocol AccessibilityPermissionProviding {
    var isTrusted: Bool { get }
    @discardableResult func openSettings() -> Bool
    func requestAuthorizationPrompt()
}

@MainActor
public struct AccessibilityPermission: AccessibilityPermissionProviding {
    public init() {}

    public var isTrusted: Bool { AXIsProcessTrusted() }

    /// Opens only the Accessibility privacy pane after the caller has obtained user confirmation.
    @discardableResult
    public func openSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return false }
        return NSWorkspace.shared.open(url)
    }

    /// The system's documented informational authorization flow; call only after explicit confirmation.
    public func requestAuthorizationPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
