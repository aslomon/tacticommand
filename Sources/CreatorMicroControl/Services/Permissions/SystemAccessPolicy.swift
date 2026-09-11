import Foundation

enum SystemPrivacyPane: String, Equatable {
    case accessibility = "Privacy_Accessibility"
    case inputMonitoring = "Privacy_ListenEvent"

    var url: URL {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?\(rawValue)"
            )
        else {
            preconditionFailure("The System Settings privacy URL is invalid.")
        }
        return url
    }
}

enum SystemAccessPolicy {
    static let inputMonitoringRequiredMessage = "Input Monitoring permission is required"

    static func requiredPrivacyPane(
        for access: SystemAccessSnapshot
    ) -> SystemPrivacyPane? {
        if access.accessibility != .granted { return .accessibility }
        if access.inputMonitoring != .granted { return .inputMonitoring }
        return nil
    }

    static func canStartDeviceRuntime(with access: SystemAccessSnapshot) -> Bool {
        access.inputMonitoring == .granted
    }
}
