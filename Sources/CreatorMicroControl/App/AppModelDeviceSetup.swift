import CreatorMicroCore
import Foundation

extension AppModel {
    func inspectDeviceSetup() async {
        guard !deviceSetupBusy else { return }
        deviceSetupInspection = nil
        await performDeviceSetup { service in
            self.deviceSetupInspection = try await service.inspect()
        }
    }

    func provisionDeviceSetup(token: UUID, consent: Bool) async {
        guard !deviceSetupBusy else { return }
        await performDeviceSetup { service in
            try await service.provision(token: token, consent: consent)
            self.deviceSetupInspection = try await service.inspect()
            self.resetLightingBoundary()
            await self.synchronizeLighting()
        }
    }

    func restoreDeviceSetup(consent: Bool) async {
        guard !deviceSetupBusy else { return }
        await performDeviceSetup { service in
            try await service.restore(consent: consent)
            self.deviceSetupInspection = try await service.inspect()
            self.resetLightingBoundary()
            await self.synchronizeLighting()
        }
    }

    private func performDeviceSetup(_ operation: (FirmwareSetupService) async throws -> Void) async {
        deviceSetupBusy = true
        deviceSetupError = nil
        if deviceSetupService == nil {
            deviceSetupService = FirmwareSetupService(client: CoordinatorFirmwareSetupClient(coordinator: coordinator))
        }
        guard let service = deviceSetupService else {
            deviceSetupBusy = false
            return
        }
        let identity = await coordinator.identitySnapshot
        do { try await operation(service) } catch { deviceSetupError = error.localizedDescription }
        if await coordinator.identitySnapshot != identity { invalidateDeviceSetup() }
        deviceSetupBackupPath = await service.backupURL?.path
        deviceSetupCanRestore = await service.canRestore()
        deviceSetupBusy = false
    }

    func invalidateDeviceSetup() {
        deviceSetupInspection = nil
        deviceSetupCanRestore = false
    }
}
