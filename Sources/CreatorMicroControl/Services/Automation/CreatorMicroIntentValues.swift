import AppIntents
import CreatorMicroCore

enum CreatorMicroLayerIntentValue: String, AppEnum {
    case desktop
    case agents
    case windows
    case meetings
    case snippets
    case cursor
    case meetingControls
    case codex
    case claudeCodeCLI
    case claudeApp
    case codexCLI
    case codexApp
    case agentFocus
    case windowManagement
    case snippetCommands

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "TactiCommand Layer")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .desktop: "Desktop",
        .agents: "Agent Focus (Legacy)",
        .windows: "Window Management (Legacy)",
        .meetings: "Meetings (Legacy)",
        .snippets: "Snippets (Legacy)",
        .cursor: "Cursor",
        .meetingControls: "Meetings",
        .codex: "Codex CLI (Legacy)",
        .claudeCodeCLI: "Claude Code CLI",
        .claudeApp: "Claude App",
        .codexCLI: "Codex CLI",
        .codexApp: "Codex App",
        .agentFocus: "Agent Focus",
        .windowManagement: "Window Management",
        .snippetCommands: "Snippets",
    ]

    var layer: LayerIndex {
        switch self {
        case .desktop: .desktop
        case .agents: .agentFocus
        case .windows: .windowManagement
        case .meetings: .meetingControls
        case .snippets: .snippetCommands
        case .cursor: .cursor
        case .meetingControls: .meetingControls
        case .codex: .codexCLI
        case .claudeCodeCLI: .claudeCodeCLI
        case .claudeApp: .claudeApp
        case .codexCLI: .codexCLI
        case .codexApp: .codexApp
        case .agentFocus: .agentFocus
        case .windowManagement: .windowManagement
        case .snippetCommands: .snippetCommands
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
