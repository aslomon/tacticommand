import ServiceManagement

enum LaunchAtLoginFailure: Error, Equatable {
    case registrationFailed(String)
}

@MainActor
struct LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginFailure> {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .success(())
        } catch {
            return .failure(.registrationFailed(error.localizedDescription))
        }
    }
}
