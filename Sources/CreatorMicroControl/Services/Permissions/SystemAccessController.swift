import AppKit
import ApplicationServices
import IOKit.hidsystem

enum SystemAccessState: Equatable {
    case granted
    case denied
    case unknown
}

struct SystemAccessSnapshot: Equatable {
    let accessibility: SystemAccessState
    let inputMonitoring: SystemAccessState

    var canControlSystem: Bool {
        accessibility == .granted
    }

    var isComplete: Bool {
        accessibility == .granted && inputMonitoring == .granted
    }
}

@MainActor
protocol SystemAccessControlling: AnyObject {
    func snapshot() -> SystemAccessSnapshot
    func requestAccessibility() -> SystemAccessSnapshot
    func requestInputMonitoring() -> SystemAccessSnapshot
    func openPrivacySettings(_ pane: SystemPrivacyPane)
}

@MainActor
final class SystemAccessController: SystemAccessControlling {
    func snapshot() -> SystemAccessSnapshot {
        SystemAccessSnapshot(
            accessibility: AXIsProcessTrusted() ? .granted : .denied,
            inputMonitoring: inputMonitoringState()
        )
    }

    @discardableResult
    func requestAccessibility() -> SystemAccessSnapshot {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return snapshot()
    }

    @discardableResult
    func requestInputMonitoring() -> SystemAccessSnapshot {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return snapshot()
    }

    func openPrivacySettings(_ pane: SystemPrivacyPane) {
        NSWorkspace.shared.open(pane.url)
    }

    private func inputMonitoringState() -> SystemAccessState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .unknown
        }
    }
}
