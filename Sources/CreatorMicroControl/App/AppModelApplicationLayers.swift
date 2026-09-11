import CreatorMicroCore

enum ApplicationLayerSession {
    case inactive
    case active(bundleIdentifier: String, returnSelection: LayerSelectionState)
    case manuallyOverridden(bundleIdentifier: String)
}

extension AppModel {
    func startApplicationLayerMonitoring() {
        guard applicationMonitorTask == nil else { return }
        let identifiers = frontmostApplicationMonitor.bundleIdentifiers()
        applicationMonitorTask = Task { [weak self] in
            for await identifier in identifiers {
                guard !Task.isCancelled, let self else { return }
                applyFrontmostApplication(identifier)
            }
        }
    }

    func applyFrontmostApplication(_ bundleIdentifier: String?) {
        frontmostApplicationBundleIdentifier = bundleIdentifier
        clearManualOverrideAfterLeaving(bundleIdentifier)
        let resolver = ApplicationLayerResolver(
            rules: configuration.applicationLayerRules
        )
        guard
            let bundleIdentifier,
            let layer = resolver.layer(for: bundleIdentifier)
        else {
            restoreSelectionAfterApplicationRule()
            return
        }
        guard shouldApplyApplicationRule(for: bundleIdentifier) else { return }
        beginApplicationLayerSession(for: bundleIdentifier)
        select(layer: layer, source: .applicationRule)
    }

    func reevaluateApplicationLayerRule() {
        applyFrontmostApplication(frontmostApplicationBundleIdentifier)
    }

    func recordManualLayerOverrideIfNeeded(source: LayerSelectionSource) {
        guard source != .applicationRule else { return }
        guard case .active(let bundleIdentifier, _) = applicationLayerSession else {
            return
        }
        applicationLayerSession = .manuallyOverridden(
            bundleIdentifier: bundleIdentifier
        )
    }

    private func clearManualOverrideAfterLeaving(_ bundleIdentifier: String?) {
        guard case .manuallyOverridden(let overriddenApp) = applicationLayerSession else {
            return
        }
        guard bundleIdentifier != overriddenApp else { return }
        applicationLayerSession = .inactive
    }

    private func shouldApplyApplicationRule(for bundleIdentifier: String) -> Bool {
        guard case .manuallyOverridden(let overriddenApp) = applicationLayerSession else {
            return true
        }
        return bundleIdentifier != overriddenApp
    }

    private func beginApplicationLayerSession(for bundleIdentifier: String) {
        switch applicationLayerSession {
        case .active(_, let returnSelection):
            applicationLayerSession = .active(
                bundleIdentifier: bundleIdentifier,
                returnSelection: returnSelection
            )
        case .inactive, .manuallyOverridden:
            applicationLayerSession = .active(
                bundleIdentifier: bundleIdentifier,
                returnSelection: layerSelection
            )
        }
    }

    private func restoreSelectionAfterApplicationRule() {
        guard case .active(_, let returnSelection) = applicationLayerSession else {
            return
        }
        applicationLayerSession = .inactive
        select(layer: returnSelection.active, source: returnSelection.source)
    }
}
