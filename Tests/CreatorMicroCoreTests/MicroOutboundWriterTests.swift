import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroOutboundWriterTests: XCTestCase {
    func testConcurrentMultiFramePayloadsRemainContiguous() async throws {
        let transport = ControlledWriteTransport()
        let writer = MicroOutboundWriter()
        let firstPayload = Data(repeating: 0x41, count: 100)
        let secondPayload = Data(repeating: 0x42, count: 100)
        let firstFrames = MicroReportFramer.frames(for: firstPayload, transport: .usb)
        let secondFrames = MicroReportFramer.frames(for: secondPayload, transport: .usb)

        let firstWrite = await writer.enqueue(firstPayload, to: transport)
        try await transport.waitForBlockedWriteCount(1)
        let secondWrite = await writer.enqueue(secondPayload, to: transport)

        let reportsBeforeRelease = await transport.capturedReports()
        XCTAssertEqual(reportsBeforeRelease, [firstFrames[0]])
        try await transport.releaseWrites(count: firstFrames.count + secondFrames.count)
        try await firstWrite.value
        try await secondWrite.value
        let completedReports = await transport.capturedReports()

        XCTAssertEqual(completedReports, firstFrames + secondFrames)
    }
}

private actor ControlledWriteTransport: MicroTransport {
    nonisolated let kind = MicroTransportKind.usb
    nonisolated let incomingReports: AsyncStream<Data>

    private var reports: [Data] = []
    private var blockedWrites: [CheckedContinuation<Void, Never>] = []

    init() {
        incomingReports = AsyncStream { continuation in
            continuation.finish()
        }
    }

    func write(_ report: Data) async throws {
        reports.append(report)
        await withCheckedContinuation { continuation in
            blockedWrites.append(continuation)
        }
    }

    func capturedReports() -> [Data] {
        reports
    }

    func waitForBlockedWriteCount(_ count: Int) async throws {
        for _ in 0..<200 {
            if blockedWrites.count >= count { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ControlledWriteFailure.timeout
    }

    func releaseWrites(count: Int) async throws {
        for _ in 0..<count {
            try await waitForBlockedWriteCount(1)
            blockedWrites.removeFirst().resume()
        }
    }
}

private enum ControlledWriteFailure: Error {
    case timeout
}
