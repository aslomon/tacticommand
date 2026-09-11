import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class DictationActionEditorTests: XCTestCase {
    func testBindingExtractsDirectShortAndLongPressDictationExactly() {
        let binding = DictationBinding(
            providerID: .rede,
            behavior: .holdToTalk,
            shortcut: KeyShortcut(
                key: "space",
                modifiers: [.command, .option],
                pressCount: 2,
                interTapIntervalMilliseconds: 275
            )
        )

        XCTAssertEqual(DictationActionEditor.binding(in: .dictation(binding)), binding)
        XCTAssertEqual(
            DictationActionEditor.binding(
                in: .shortOrLongPress(shortPress: .dictation(binding), longPress: .approval)
            ),
            binding
        )
        XCTAssertEqual(
            DictationActionEditor.binding(
                in: .shortOrLongPress(shortPress: .returnKey, longPress: .dictation(binding))
            ),
            binding
        )
    }

    func testBindingReturnsNilWhenNoDictationBranchExists() {
        XCTAssertNil(DictationActionEditor.binding(in: .openFinder))
        XCTAssertNil(
            DictationActionEditor.binding(
                in: .shortOrLongPress(shortPress: .returnKey, longPress: .approval)
            )
        )
    }

    func testReplacementUpdatesOnlyTheExistingShortPressDictationBranch() {
        let replacement = DictationBinding(
            providerID: .chatGPTCodex,
            behavior: .toggle,
            shortcut: KeyShortcut(key: "d", modifiers: [.control, .shift])
        )

        XCTAssertEqual(
            DictationActionEditor.replacingDictation(
                in: .shortOrLongPress(shortPress: Self.originalDictation, longPress: .approval),
                with: replacement
            ),
            .shortOrLongPress(shortPress: .dictation(replacement), longPress: .approval)
        )
    }

    func testReplacementUpdatesOnlyTheExistingLongPressDictationBranch() {
        let replacement = DictationBinding(
            providerID: .appleDictation,
            behavior: .toggle,
            shortcut: KeyShortcut(key: "fn", pressCount: 2)
        )

        XCTAssertEqual(
            DictationActionEditor.replacingDictation(
                in: .shortOrLongPress(shortPress: .returnKey, longPress: Self.originalDictation),
                with: replacement
            ),
            .shortOrLongPress(shortPress: .returnKey, longPress: .dictation(replacement))
        )
    }

    func testReplacementFallsBackToDirectDictationWithoutADictationBranch() {
        let replacement = DictationBinding(providerID: .rede, behavior: .toggle)

        XCTAssertEqual(
            DictationActionEditor.replacingDictation(
                in: .shortOrLongPress(shortPress: .returnKey, longPress: .approval),
                with: replacement
            ),
            .dictation(replacement)
        )
    }

    private static var originalDictation: CreatorAction {
        .dictation(
            DictationBinding(
                providerID: .rede,
                behavior: .holdToTalk,
                shortcut: KeyShortcut(key: "space", modifiers: [.option])
            )
        )
    }
}
