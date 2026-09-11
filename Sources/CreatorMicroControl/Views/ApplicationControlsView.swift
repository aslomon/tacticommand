import AppKit
import SwiftUI

enum ApplicationControlsPlacement: Equatable {
    case configurationSettings
}

enum ApplicationControlsPresentation {
    static let launchAtLoginPlacement = ApplicationControlsPlacement.configurationSettings
    static let launchAtLoginTitle = "Launch at Login"
    static let launchAtLoginHelp = "Open TactiCommand automatically when you sign in."
    static let quitTitle = "Quit"
    static let quitSystemImage = "power"
    static let quitAccessibilityLabel = ApplicationQuitCommand.title
    static let quitMinimumTargetSize: CGFloat = 28
}

struct LaunchAtLoginSettingsToggle: View {
    let model: AppModel

    var body: some View {
        Toggle(
            ApplicationControlsPresentation.launchAtLoginTitle,
            isOn: launchAtLoginBinding
        )
        .toggleStyle(.switch)
        .controlSize(.small)
        .help(ApplicationControlsPresentation.launchAtLoginHelp)
        .accessibilityHint(ApplicationControlsPresentation.launchAtLoginHelp)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { model.setLaunchAtLogin($0) }
        )
    }
}

struct PopoverQuitButton: View {
    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label(
                ApplicationControlsPresentation.quitTitle,
                systemImage: ApplicationControlsPresentation.quitSystemImage
            )
        }
        .buttonStyle(.borderless)
        .frame(minHeight: ApplicationControlsPresentation.quitMinimumTargetSize)
        .contentShape(Rectangle())
        .keyboardShortcut(
            KeyEquivalent(ApplicationQuitCommand.keyEquivalent),
            modifiers: .command
        )
        .accessibilityLabel(ApplicationControlsPresentation.quitAccessibilityLabel)
        .help(ApplicationControlsPresentation.quitAccessibilityLabel)
    }
}
