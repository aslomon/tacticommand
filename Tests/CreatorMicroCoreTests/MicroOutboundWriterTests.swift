import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroOutboundWriterTests: XCTestCase {
    func testMessagesRespectFirmwareCooldown() async throws {
        let transport = TimedWriteTransport()
        let writer = MicroOutboundWriter()
        let first = await writer.enqueue(Data("{}".utf8), to: transport)
        let second = await writer.enqueue(Data("{}".utf8), to: transport)
        try await first.value
        try await second.value
        let instants = await transport.instants
        XCTAssertEqual(instants.count, 2)
        XCTAssertGreaterThanOrEqual(instants[0].duration(to: instants[1]), .milliseconds(50))
    }

    func testFailedMessagesStillRespectCooldown() async throws {
        let transport = TimedWriteTransport(failFirst: true)
        let writer = MicroOutboundWriter()
        let first = await writer.enqueue(Data("{}".utf8), to: transport)
        let second = await writer.enqueue(Data("{}".utf8), to: transport)
        do {
            try await first.value
            XCTFail("Expected transport write failure")
        } catch MicroConnectionError.outputReportFailed {}
        try await second.value
        let instants = await transport.instants
        XCTAssertEqual(instants.count, 2)
        XCTAssertGreaterThanOrEqual(instants[0].duration(to: instants[1]), .milliseconds(50))
    }

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

    func testCancellationAfterFirstFrameStillFinishesTheAtomicPayload() async throws {
        let transport = ControlledWriteTransport()
        let writer = MicroOutboundWriter()
        let payload = Data(repeating: 0x41, count: 180)
        let frames = MicroReportFramer.frames(for: payload, transport: .usb)
        let operation = await writer.enqueue(payload, to: transport)
        try await transport.waitForBlockedWriteCount(1)
        operation.cancel()
        try await transport.releaseWrites(count: frames.count)
        try await operation.value
        let reports = await transport.capturedReports()
        XCTAssertEqual(reports, frames)
    }

    func testQueuedCancellationWritesNoPartialMessage() async throws {
        let transport = ControlledWriteTransport()
        let writer = MicroOutboundWriter()
        let first = await writer.enqueue(Data("first".utf8), to: transport)
        try await transport.waitForBlockedWriteCount(1)
        let cancelled = await writer.enqueue(Data("cancelled".utf8), to: transport)
        cancelled.cancel()
        try await transport.releaseWrites(count: 1)
        try await first.value
        do {
            try await cancelled.value
            XCTFail()
        } catch is CancellationError {}
        let reports = await transport.capturedReports()
        XCTAssertEqual(reports, MicroReportFramer.frames(for: Data("first".utf8), transport: .usb))
    }
}

private actor TimedWriteTransport: MicroTransport {
    nonisolated let kind = MicroTransportKind.usb
    nonisolated let incomingReports = AsyncStream<Data> { $0.finish() }
    private(set) var instants: [ContinuousClock.Instant] = []
    private let failFirst: Bool

    init(failFirst: Bool = false) { self.failFirst = failFirst }

    func write(_ report: Data) async throws {
        instants.append(ContinuousClock().now)
        if failFirst && instants.count == 1 { throw MicroConnectionError.outputReportFailed(code: -1) }
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
