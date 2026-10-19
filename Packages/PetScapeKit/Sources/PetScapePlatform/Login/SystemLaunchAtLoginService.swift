import ServiceManagement

/// Public macOS 13+ API; constructing/reading this service never registers a login item.
public final class SystemLaunchAtLoginService: LaunchAtLoginService {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var status: LaunchAtLoginStatus {
        switch service.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            if enabled { throw .registrationFailed(error.localizedDescription) }
            throw .unregistrationFailed(error.localizedDescription)
        }
    }
}
