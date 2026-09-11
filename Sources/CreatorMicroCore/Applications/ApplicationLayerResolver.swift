import Foundation

public struct ApplicationLayerResolver: Sendable {
    private let layersByBundleIdentifier: [String: LayerIndex]

    public init(rules: [ApplicationLayerRule]) {
        var layersByBundleIdentifier: [String: LayerIndex] = [:]
        for rule in rules {
            let identifier = Self.normalized(rule.bundleIdentifier)
            guard !identifier.isEmpty else { continue }
            if layersByBundleIdentifier[identifier] == nil {
                layersByBundleIdentifier[identifier] = rule.layer
            }
        }
        self.layersByBundleIdentifier = layersByBundleIdentifier
    }

    public func layer(for bundleIdentifier: String?) -> LayerIndex? {
        guard let bundleIdentifier else { return nil }
        let identifier = Self.normalized(bundleIdentifier)
        guard !identifier.isEmpty else { return nil }
        return layersByBundleIdentifier[identifier]
    }

    private static func normalized(_ bundleIdentifier: String) -> String {
        bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
