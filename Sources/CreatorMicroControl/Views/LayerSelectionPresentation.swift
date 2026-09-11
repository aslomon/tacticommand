import CreatorMicroCore

struct LayerSelectionPresentation: Equatable {
    static let physicalControlExplanation =
        "The round haptic control switches Bluetooth host 1–3. Its three white LEDs show that host; it does not change these six software layers and cannot be assigned."

    let layerName: String
    let sourceLabel: String
    let status: String
    let detail: String
    let firmwareObservation: String?

    init(state: LayerSelectionState, layerName: String) {
        self.layerName = layerName
        sourceLabel = Self.sourceLabel(for: state.source)
        status = "Local · \(sourceLabel)"
        detail = Self.detail(for: state.source)
        firmwareObservation = state.firmwareLayerIndex.map(Self.firmwareObservation)
    }

    private static func sourceLabel(for source: LayerSelectionSource) -> String {
        switch source {
        case .launchDefault: "Default"
        case .editor: "Editor"
        case .physicalKey: "Key"
        case .applicationRule: "App rule"
        case .automation: "Automation"
        }
    }

    private static func detail(for source: LayerSelectionSource) -> String {
        switch source {
        case .launchDefault:
            "Loaded as the app's default software mapping; not sent to firmware."
        case .editor:
            "Selected in TactiCommand; not sent to firmware."
        case .physicalKey:
            "Changed by an assigned hardware key; not sent to firmware."
        case .applicationRule:
            "Changed by a frontmost-application rule; not sent to firmware."
        case .automation:
            "Changed by local automation; not sent to firmware."
        }
    }

    private static func firmwareObservation(_ rawValue: Int) -> String {
        "Device reports internal layer index \(rawValue). It is diagnostic only and not mapped to software layers."
    }
}
