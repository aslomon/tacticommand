import AppIntents
import CreatorMicroCore

enum CreatorMicroLayerIntentValue: String, AppEnum {
    case codex
    case desktop
    case agents
    case windows
    case meetings
    case snippets

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Creator Micro Layer")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .codex: "Codex",
        .desktop: "Desktop",
        .agents: "Agents",
        .windows: "Windows",
        .meetings: "Meetings",
        .snippets: "Snippets",
    ]

    var layer: LayerIndex {
        switch self {
        case .codex: .codex
        case .desktop: .desktop
        case .agents: .agents
        case .windows: .windows
        case .meetings: .meetings
        case .snippets: .snippets
        }
    }
}

enum CreatorMicroControlIntentValue: String, AppEnum {
    case agent0
    case agent1
    case agent2
    case agent3
    case agent4
    case agent5
    case action6
    case action7
    case action8
    case action9
    case action10
    case action11
    case action12
    case encoderPress
    case encoderClockwise
    case encoderCounterClockwise

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "TactiCommand Control")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .agent0: "Agent 1",
        .agent1: "Agent 2",
        .agent2: "Agent 3",
        .agent3: "Agent 4",
        .agent4: "Agent 5",
        .agent5: "Agent 6",
        .action6: "Action 1",
        .action7: "Action 2",
        .action8: "Action 3",
        .action9: "Action 4",
        .action10: "Left Microphone",
        .action11: "Right Microphone",
        .action12: "Return",
        .encoderPress: "Dial Press",
        .encoderClockwise: "Dial Clockwise",
        .encoderCounterClockwise: "Dial Counterclockwise",
    ]

    var control: ControlID {
        switch self {
        case .agent0: .agent0
        case .agent1: .agent1
        case .agent2: .agent2
        case .agent3: .agent3
        case .agent4: .agent4
        case .agent5: .agent5
        case .action6: .action6
        case .action7: .action7
        case .action8: .action8
        case .action9: .action9
        case .action10: .action10
        case .action11: .action11
        case .action12: .action12
        case .encoderPress: .encoderPress
        case .encoderClockwise: .encoderClockwise
        case .encoderCounterClockwise: .encoderCounterClockwise
        }
    }
}
