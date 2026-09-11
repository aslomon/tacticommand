import Darwin
import Foundation

public enum SafeScriptFailure: Error, Equatable, Sendable {
    case emptySource
    case launchFailed(String)
    case timedOut
    case nonZeroExit(Int32)
}

public struct SafeScriptRunner: Sendable {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 30) {
        self.timeout = max(timeout, 0.1)
    }

    public func runShellCommand(
        _ command: String
    ) async -> Result<Void, SafeScriptFailure> {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptySource)
        }
        return await run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-lc", command]
        )
    }

    public func runAppleScript(
        _ source: String
    ) async -> Result<Void, SafeScriptFailure> {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptySource)
        }
        return await run(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", source]
        )
    }

    private func run(
        executableURL: URL,
        arguments: [String]
    ) async -> Result<Void, SafeScriptFailure> {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let state = ProcessRunState()
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { finishedProcess in
                guard let result = state.finish(status: finishedProcess.terminationStatus) else {
                    return
                }
                continuation.resume(returning: result)
            }
            do {
                try process.run()
                scheduleTimeout(for: process, state: state)
            } catch {
                guard let result = state.failToLaunch(error.localizedDescription) else { return }
                continuation.resume(returning: result)
            }
        }
    }

    private func scheduleTimeout(for process: Process, state: ProcessRunState) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            state.requestTimeout(for: process)
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var timedOut = false

    func finish(status: Int32) -> Result<Void, SafeScriptFailure>? {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return nil }
        completed = true
        if timedOut { return .failure(.timedOut) }
        return status == 0 ? .success(()) : .failure(.nonZeroExit(status))
    }

    func failToLaunch(_ message: String) -> Result<Void, SafeScriptFailure>? {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return nil }
        completed = true
        return .failure(.launchFailed(message))
    }

    func requestTimeout(for process: Process) {
        lock.lock()
        guard !completed, process.isRunning else {
            lock.unlock()
            return
        }
        timedOut = true
        lock.unlock()
        process.terminate()
        scheduleForcedTermination(for: process)
    }

    private func scheduleForcedTermination(for process: Process) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            guard process.isRunning else { return }
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
