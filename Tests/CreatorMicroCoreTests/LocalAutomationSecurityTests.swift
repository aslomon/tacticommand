import Foundation
import XCTest

@testable import CreatorMicroCore

final class LocalAutomationSecurityTests: XCTestCase {
    func testRPCPolicyExplicitlyRejectsShellAndAppleScript() {
        assertForbidden(.shellCommand("touch /tmp/unsafe"), kind: .shellCommand)
        assertForbidden(.appleScript("tell application \"Finder\" to quit"), kind: .appleScript)
    }

    func testRPCPolicyRejectsUnassignedBinding() {
        guard case .failure(let failure) = LocalAutomationBindingPolicy.authorize(.none) else {
            return XCTFail("Expected an unassigned binding to be rejected")
        }

        XCTAssertEqual(failure.code, .bindingNotFound)
    }

    func testRPCTriggerEmitsACompleteTapForHoldToTalk() throws {
        let binding = DictationBinding(
            providerID: .appleDictation,
            behavior: .holdToTalk
        )

        let events = try LocalAutomationBindingPolicy.events(for: .dictation(binding)).get()

        XCTAssertEqual(
            events,
            [
                RoutedCreatorAction(action: .dictation(binding), phase: .pressed),
                RoutedCreatorAction(action: .dictation(binding), phase: .released),
            ]
        )
    }

    func testRPCTriggerEmitsOnePressForRegularAndToggleActions() throws {
        let toggle = DictationBinding(providerID: .rede, behavior: .toggle)

        XCTAssertEqual(
            try LocalAutomationBindingPolicy.events(for: .openFinder).get(),
            [RoutedCreatorAction(action: .openFinder, phase: .pressed)]
        )
        XCTAssertEqual(
            try LocalAutomationBindingPolicy.events(for: .dictation(toggle)).get(),
            [RoutedCreatorAction(action: .dictation(toggle), phase: .pressed)]
        )
    }

    func testRPCPolicyAuthorizesLayerActionsAndReportsTheirKind() throws {
        let action = CreatorAction.layer(.select(.meetings))

        XCTAssertEqual(
            try LocalAutomationBindingPolicy.events(for: action).get(),
            [RoutedCreatorAction(action: action, phase: .pressed)]
        )
        XCTAssertEqual(LocalAutomationBindingPolicy.kind(of: action), .layer)
    }

    func testRPCPolicyAuthorizesDeleteAndReportsItsKind() throws {
        XCTAssertEqual(
            try LocalAutomationBindingPolicy.events(for: .deleteKey).get(),
            [RoutedCreatorAction(action: .deleteKey, phase: .pressed)]
        )
        XCTAssertEqual(LocalAutomationBindingPolicy.kind(of: .deleteKey), .deleteKey)
    }

    func testRPCPolicyRecursivelyRejectsUnsafeDualBindingBranches() {
        assertForbidden(
            .shortOrLongPress(
                shortPress: .openFinder,
                longPress: .shellCommand("touch /tmp/unsafe")
            ),
            kind: .shellCommand
        )
        assertForbidden(
            .shortOrLongPress(
                shortPress: .appleScript("tell application \"Finder\" to quit"),
                longPress: .openTerminal
            ),
            kind: .appleScript
        )
    }

    func testRPCTriggerDeterministicallyExecutesOnlyDualBindingShortAction() throws {
        let action = CreatorAction.shortOrLongPress(
            shortPress: .openFinder,
            longPress: .openTerminal
        )

        XCTAssertEqual(
            try LocalAutomationBindingPolicy.events(for: action).get(),
            [.init(action: .openFinder, phase: .pressed)]
        )
        XCTAssertEqual(LocalAutomationBindingPolicy.kind(of: action), .shortOrLongPress)
    }

    private func assertForbidden(
        _ action: CreatorAction,
        kind: LocalAutomationActionKind,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let failure) = LocalAutomationBindingPolicy.authorize(action) else {
            return XCTFail("Expected action to be rejected", file: file, line: line)
        }
        XCTAssertEqual(failure.code, .forbiddenAction, file: file, line: line)
        XCTAssertEqual(failure.actionKind, kind, file: file, line: line)
    }
}

final class LocalAutomationLineFramerTests: XCTestCase {
    func testFramesFragmentedJSONLinesAndAcceptsCRLF() {
        var framer = LocalAutomationLineFramer(maximumLineBytes: 64)

        XCTAssertEqual(framer.append(Data(#"{"id":"one"}"#.utf8)), [])
        XCTAssertEqual(
            framer.append(Data("\r\n{\"id\":\"two\"}\n".utf8)),
            [
                .line(Data(#"{"id":"one"}"#.utf8)),
                .line(Data(#"{"id":"two"}"#.utf8)),
            ]
        )
    }

    func testAllowsExactLimitAndRejectsTheNextByte() {
        var exact = LocalAutomationLineFramer(maximumLineBytes: 4)
        var oversized = LocalAutomationLineFramer(maximumLineBytes: 4)

        XCTAssertEqual(
            exact.append(Data("1234\n".utf8)),
            [.line(Data("1234".utf8))]
        )
        XCTAssertEqual(
            oversized.append(Data("12345".utf8)),
            [.frameTooLarge]
        )
    }
}

final class LocalAutomationStartupRetryTests: XCTestCase {
    func testStartupRetryIsBoundedToOneSecond() {
        let delays = LocalAutomationStartupRetry.delaysNanoseconds

        XCTAssertEqual(delays.count, 5)
        XCTAssertEqual(delays.reduce(0, +), 1_000_000_000)
        XCTAssertTrue(delays.allSatisfy { $0 > 0 })
    }
}

final class LocalAutomationSocketPathPolicyTests: XCTestCase {
    func testLiveOwnedSocketIsNeverTreatedAsStale() {
        XCTAssertEqual(
            LocalAutomationSocketPathPolicy.decision(
                ownership: .currentUserSocket,
                probe: .reachable
            ),
            .rejectOccupied
        )
    }

    func testOnlyRefusedOwnedSocketMayBeRemoved() {
        XCTAssertEqual(
            LocalAutomationSocketPathPolicy.decision(
                ownership: .currentUserSocket,
                probe: .refused
            ),
            .removeStale
        )
        XCTAssertEqual(
            LocalAutomationSocketPathPolicy.decision(
                ownership: .unsafe,
                probe: .refused
            ),
            .rejectOccupied
        )
    }

    func testMissingSocketPathCanBeCreated() {
        XCTAssertEqual(
            LocalAutomationSocketPathPolicy.decision(
                ownership: .missing,
                probe: .notNeeded
            ),
            .create
        )
    }
}
