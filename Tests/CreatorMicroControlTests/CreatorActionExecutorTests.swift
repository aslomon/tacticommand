import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class CreatorActionExecutorTests: XCTestCase {
    func testDeleteActionResolvesToSynthesizedBackwardDeleteKey() {
        XCTAssertEqual(
            CreatorActionExecutor.keyboardShortcut(for: .deleteKey),
            KeyShortcut(key: "delete")
        )
    }

    func testClipboardActionsResolveToNativeMacShortcuts() {
        XCTAssertEqual(
            CreatorActionExecutor.keyboardShortcut(for: .copy),
            KeyShortcut(key: "c", modifiers: [.command])
        )
        XCTAssertEqual(
            CreatorActionExecutor.keyboardShortcut(for: .paste),
            KeyShortcut(key: "v", modifiers: [.command])
        )
        XCTAssertEqual(
            CreatorActionExecutor.keyboardShortcut(for: .pastePlainText),
            KeyShortcut(key: "v", modifiers: [.command, .option, .shift])
        )
    }

    func testCustomKeyboardShortcutIsSentWithoutRewriting() {
        let shortcut = KeyShortcut(key: "k", modifiers: [.command, .shift])

        XCTAssertEqual(
            CreatorActionExecutor.keyboardShortcut(for: .keyboardShortcut(shortcut)),
            shortcut
        )
    }

    func testAudioActionRunsOffMainThreadAndReturnsAppliedSnapshotWithoutReread() async throws {
        let expected = SystemAudioSnapshot(
            inputMute: .unmuted,
            outputMute: .unmuted,
            outputVolume: 0.75
        )
        let audio = RecordingSystemAudioController(result: .success(expected))
        let executor = CreatorActionExecutor(audio: audio)

        let outcome = try await executor.execute(
            RoutedCreatorAction(action: .volume(.increase), phase: .pressed)
        ).get()

        XCTAssertEqual(outcome, .audioSnapshot(expected))
        XCTAssertEqual(audio.appliedCommands, [.volume(.increase)])
        XCTAssertFalse(try XCTUnwrap(audio.wasMainThreadByCommand.first))
        XCTAssertEqual(audio.snapshotCallCount, 0)
    }

    func testAudioActionFailurePreservesTheUnderlyingFailure() async {
        let failure = SystemAudioFailure.propertyUnavailable("output volume")
        let audio = RecordingSystemAudioController(result: .failure(failure))
        let executor = CreatorActionExecutor(audio: audio)

        let result = await executor.execute(
            RoutedCreatorAction(action: .volume(.decrease), phase: .pressed)
        )

        XCTAssertEqual(result, .failure(.audio(failure)))
        XCTAssertEqual(audio.snapshotCallCount, 0)
    }
}

private final class RecordingSystemAudioController: @unchecked Sendable, SystemAudioControlling {
    enum Command: Equatable {
        case volume(VolumeCommand)
        case outputMute(MuteCommand)
        case inputMute(MuteCommand)
    }

    private let lock = NSLock()
    private let result: Result<SystemAudioSnapshot, SystemAudioFailure>
    private var commands: [Command] = []
    private var mainThreadResults: [Bool] = []
    private var snapshots = 0

    init(result: Result<SystemAudioSnapshot, SystemAudioFailure>) {
        self.result = result
    }

    var appliedCommands: [Command] {
        lock.withLock { commands }
    }

    var wasMainThreadByCommand: [Bool] {
        lock.withLock { mainThreadResults }
    }

    var snapshotCallCount: Int {
        lock.withLock { snapshots }
    }

    func snapshot() -> SystemAudioSnapshot {
        lock.withLock { snapshots += 1 }
        return .unavailable
    }

    func applyOutputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        record(.outputMute(command))
        return result
    }

    func applyInputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        record(.inputMute(command))
        return result
    }

    func applyVolume(
        _ command: VolumeCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        record(.volume(command))
        return result
    }

    private func record(_ command: Command) {
        lock.withLock {
            commands.append(command)
            mainThreadResults.append(Thread.isMainThread)
        }
    }
}
