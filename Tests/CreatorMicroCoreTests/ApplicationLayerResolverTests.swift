import XCTest

@testable import CreatorMicroCore

final class ApplicationLayerResolverTests: XCTestCase {
    func testMatchesBundleIdentifiersWithoutCaseOrSurroundingWhitespace() {
        let rules = [
            ApplicationLayerRule(
                bundleIdentifier: "  COM.APPLE.FINDER  ",
                layer: .desktop
            )
        ]

        let layer = ApplicationLayerResolver(rules: rules).layer(
            for: "com.apple.finder"
        )

        XCTAssertEqual(layer, .desktop)
    }

    func testReturnsNilForMissingBlankOrUnknownApplications() {
        let resolver = ApplicationLayerResolver(
            rules: [
                ApplicationLayerRule(
                    bundleIdentifier: "com.apple.Terminal",
                    layer: .codex
                )
            ]
        )

        XCTAssertNil(resolver.layer(for: nil))
        XCTAssertNil(resolver.layer(for: "   "))
        XCTAssertNil(resolver.layer(for: "com.apple.finder"))
    }

    func testFirstMatchingRuleWinsDeterministically() {
        let resolver = ApplicationLayerResolver(
            rules: [
                ApplicationLayerRule(
                    bundleIdentifier: "com.apple.finder",
                    layer: .desktop
                ),
                ApplicationLayerRule(
                    bundleIdentifier: "com.apple.finder",
                    layer: .windows
                ),
            ]
        )

        XCTAssertEqual(resolver.layer(for: "com.apple.finder"), .desktop)
    }
}
