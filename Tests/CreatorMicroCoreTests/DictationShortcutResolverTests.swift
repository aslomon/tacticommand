import XCTest

@testable import CreatorMicroCore

final class DictationShortcutResolverTests: XCTestCase {
    func testExplicitShortcutOverridesEveryProviderDefault() throws {
        let expected = KeyShortcut(key: "space", modifiers: [.option])
        let binding = DictationBinding(
            providerID: .chatGPTCodex,
            behavior: .toggle,
            shortcut: expected
        )

        let shortcut = try DictationShortcutResolver().shortcut(for: binding).get()

        XCTAssertEqual(shortcut, expected)
    }

    func testExplicitAppleShortcutOverridesDoubleFunctionFallback() throws {
        let expected = KeyShortcut(key: "f6", modifiers: [.function])
        let binding = DictationBinding(
            providerID: .appleDictation,
            behavior: .toggle,
            shortcut: expected
        )

        let shortcut = try DictationShortcutResolver().shortcut(for: binding).get()

        XCTAssertEqual(shortcut, expected)
    }

    func testExplicitModifierOnlyShortcutIsAccepted() throws {
        let expected = KeyShortcut(
            mainKeys: [],
            modifiers: [.control, .shift]
        )
        let binding = DictationBinding(
            providerID: .rede,
            behavior: .toggle,
            shortcut: expected
        )

        let shortcut = try DictationShortcutResolver().shortcut(for: binding).get()

        XCTAssertEqual(shortcut, expected)
    }

    func testChatGPTHasDocumentedDefaultShortcut() throws {
        let binding = DictationBinding(providerID: .chatGPTCodex, behavior: .toggle)

        let shortcut = try DictationShortcutResolver().shortcut(for: binding).get()

        XCTAssertEqual(shortcut, KeyShortcut(key: "d", modifiers: [.control, .shift]))
    }

    func testProviderWithUserConfiguredShortcutDoesNotGuess() {
        let resolver = DictationShortcutResolver()
        let bindings = [
            DictationBinding(providerID: .rede, behavior: .toggle),
            DictationBinding(
                providerID: DictationProviderID(
                    applicationBundleIdentifier: "com.example.dictation"
                ),
                behavior: .holdToTalk
            ),
        ]

        for binding in bindings {
            XCTAssertEqual(
                resolver.shortcut(for: binding),
                .failure(.shortcutRequired(binding.providerID))
            )
        }
    }

    func testAppleDictationFallsBackToDoubleFunctionKey() throws {
        let binding = DictationBinding(providerID: .appleDictation, behavior: .toggle)

        let shortcut = try DictationShortcutResolver().shortcut(for: binding).get()

        XCTAssertEqual(shortcut, KeyShortcut(key: "fn", pressCount: 2))
    }

    func testAppleDictationRejectsUnsupportedHoldBehavior() {
        let binding = DictationBinding(
            providerID: .appleDictation,
            behavior: .holdToTalk,
            shortcut: KeyShortcut(key: "fn")
        )

        XCTAssertEqual(
            DictationShortcutResolver().shortcut(for: binding),
            .failure(
                .unsupportedBehavior(
                    providerID: .appleDictation,
                    behavior: .holdToTalk
                )
            )
        )
    }

    func testChatGPTDictationRejectsUnsupportedHoldBehavior() {
        let binding = DictationBinding(
            providerID: .chatGPTCodex,
            behavior: .holdToTalk
        )

        XCTAssertEqual(
            DictationShortcutResolver().shortcut(for: binding),
            .failure(
                .unsupportedBehavior(
                    providerID: .chatGPTCodex,
                    behavior: .holdToTalk
                )
            )
        )
    }

    func testHoldToTalkRejectsMultiTapShortcut() {
        let providerID = DictationProviderID(
            applicationBundleIdentifier: "com.example.dictation"
        )
        let binding = DictationBinding(
            providerID: providerID,
            behavior: .holdToTalk,
            shortcut: KeyShortcut(key: "space", pressCount: 2)
        )

        XCTAssertEqual(
            DictationShortcutResolver().shortcut(for: binding),
            .failure(
                .unsupportedBehavior(
                    providerID: providerID,
                    behavior: .holdToTalk
                )
            )
        )
    }
}
