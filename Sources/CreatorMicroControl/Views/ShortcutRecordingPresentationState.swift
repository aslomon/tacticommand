import CreatorMicroCore

struct ShortcutRecordingPresentationState: Equatable {
    private(set) var isRecording = false

    mutating func recordingStarted() {
        isRecording = true
    }

    mutating func handle(_ decision: ShortcutRecordingDecision) {
        switch decision {
        case .keepRecording:
            isRecording = true
        case .captured, .cancelled, .cleared:
            isRecording = false
        }
    }

    mutating func viewDidDisappear() {
        isRecording = false
    }
}
