import Foundation

/// System state, never a persisted desired value: approval can change outside the app.
public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
}

public enum LaunchAtLoginError: Error, Equatable, Sendable, LocalizedError {
    case registrationFailed(String)
    case unregistrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .registrationFailed(let reason): "Could not enable launch at login. \(reason)"
        case .unregistrationFailed(let reason): "Could not disable launch at login. \(reason)"
        }
    }
}

/// A real OS seam. Only an explicit Settings intent may change registration.
public protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError)
}
