import CreatorMicroCore

actor SerializedSystemAudioController {
    private let controller: any SystemAudioControlling

    init(controller: any SystemAudioControlling) {
        self.controller = controller
    }

    func applyVolume(
        _ command: VolumeCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        controller.applyVolume(command)
    }

    func applyOutputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        controller.applyOutputMute(command)
    }

    func applyInputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        controller.applyInputMute(command)
    }
}
