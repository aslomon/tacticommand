import CoreFoundation
import CreatorMicroCore
import Dispatch
import Foundation
import IOKit.hid

final class IOKitManagerLifetime: @unchecked Sendable {
    let manager: IOHIDManager
    let queue = DispatchQueue(label: "app.creator-micro-control.iokit")

    init(manager: IOHIDManager) {
        self.manager = manager
    }
}

final class IOKitCallbackContext: @unchecked Sendable {
    let incomingReports: AsyncStream<Data>

    var transportKind: MicroTransportKind? {
        lock.lock()
        defer { lock.unlock() }
        return connectionState.transportKind
    }

    private let continuation: AsyncStream<Data>.Continuation
    private let lock = NSLock()
    private let outputLock = NSLock()
    private var connectionState = IOKitConnectionState<IOHIDDevice>()
    private var cancellationFinished = false
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let stream = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingNewest(512)
        )
        incomingReports = stream.stream
        continuation = stream.continuation
    }

    func connect(_ device: IOHIDDevice) {
        lock.lock()
        defer { lock.unlock() }
        guard connectionState.acceptsOperations else { return }
        guard let descriptor = IOKitHIDDeviceDescriptorReader.read(device),
            IOKitMicroMatchingPolicy.creatorMicro.matches(descriptor)
        else {
            return
        }
        guard let kind = readTransportKind(device) else { return }
        connectionState.connect(device, transportKind: kind)
    }

    func disconnect(_ removedDevice: IOHIDDevice) {
        lock.lock()
        let isCurrent = connectionState.disconnect { device in
            CFEqual(device, removedDevice)
        }
        lock.unlock()
        if isCurrent { continuation.finish() }
    }

    func receive(
        from device: IOHIDDevice,
        reportID: UInt32,
        bytes: UnsafeMutablePointer<UInt8>,
        count: Int
    ) {
        guard reportID == UInt32(MicroProtocolConstants.reportIdentifier),
            (1...MicroProtocolConstants.bluetoothReportLength).contains(count)
        else {
            return
        }
        let data = Data(bytes: bytes, count: count)
        lock.lock()
        let acceptsReport = connectionState.isActiveDevice { activeDevice in
            CFEqual(activeDevice, device)
        }
        lock.unlock()
        if acceptsReport { continuation.yield(data) }
    }

    func write(_ report: Data) throws {
        outputLock.lock()
        defer { outputLock.unlock() }
        lock.lock()
        let connection = connectionState.activeConnection
        lock.unlock()
        guard let connection else {
            throw MicroConnectionError.notConnected
        }
        try validate(report: report, transport: connection.transportKind)
        let result = report.withUnsafeBytes { rawBuffer in
            guard let address = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                connection.device,
                kIOHIDReportTypeOutput,
                CFIndex(MicroProtocolConstants.reportIdentifier),
                address,
                report.count
            )
        }
        guard result == kIOReturnSuccess else {
            throw MicroConnectionError.outputReportFailed(code: result)
        }
    }

    private func validate(report: Data, transport: MicroTransportKind) throws {
        let expectedLength =
            transport == .usb
            ? MicroProtocolConstants.usbReportLength
            : MicroProtocolConstants.bluetoothReportLength
        let bytes = [UInt8](report.prefix(3))
        let hasExpectedPrefix =
            transport == .usb
            ? bytes.first == MicroProtocolConstants.dataOpcode
            : bytes.prefix(2) == [
                MicroProtocolConstants.reportIdentifier,
                MicroProtocolConstants.dataOpcode,
            ]
        guard report.count == expectedLength, hasExpectedPrefix else {
            throw MicroConnectionError.outputReportFailed(code: kIOReturnBadArgument)
        }
    }

    func beginCancellation() -> Bool {
        outputLock.lock()
        lock.lock()
        let started = connectionState.beginCancellation()
        lock.unlock()
        outputLock.unlock()
        if started { continuation.finish() }
        return started
    }

    func waitForCancellation() async {
        if cancellationIsFinished() { return }
        await withCheckedContinuation { continuation in
            lock.lock()
            if cancellationFinished {
                lock.unlock()
                continuation.resume()
            } else {
                cancellationWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func finishCancellation() {
        lock.lock()
        cancellationFinished = true
        let waiters = cancellationWaiters
        cancellationWaiters.removeAll()
        lock.unlock()
        continuation.finish()
        for waiter in waiters { waiter.resume() }
    }

    private func cancellationIsFinished() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationFinished
    }

    private func readTransportKind(_ device: IOHIDDevice) -> MicroTransportKind? {
        guard
            let property = IOHIDDeviceGetProperty(
                device,
                kIOHIDTransportKey as CFString
            )
        else {
            return nil
        }
        return MicroTransportKind(ioKitValue: String(describing: property))
    }
}

struct IOKitConnectionState<Device> {
    private(set) var device: Device?
    private(set) var transportKind: MicroTransportKind?
    private(set) var isCancellationStarted = false

    var acceptsOperations: Bool { !isCancellationStarted }

    var activeConnection: (device: Device, transportKind: MicroTransportKind)? {
        guard acceptsOperations, let device, let transportKind else { return nil }
        return (device, transportKind)
    }

    @discardableResult
    mutating func connect(
        _ device: Device,
        transportKind: MicroTransportKind
    ) -> Bool {
        guard acceptsOperations, self.device == nil else { return false }
        self.device = device
        self.transportKind = transportKind
        return true
    }

    func isActiveDevice(where matches: (Device) -> Bool) -> Bool {
        guard acceptsOperations, let device else { return false }
        return matches(device)
    }

    mutating func disconnect(where matches: (Device) -> Bool) -> Bool {
        guard let device, matches(device) else { return false }
        self.device = nil
        transportKind = nil
        return true
    }

    mutating func beginCancellation() -> Bool {
        guard !isCancellationStarted else { return false }
        isCancellationStarted = true
        device = nil
        transportKind = nil
        return true
    }
}

struct SendableOpaquePointer: @unchecked Sendable {
    let rawValue: UnsafeMutableRawPointer
}

private func callbackContext(
    _ pointer: UnsafeMutableRawPointer?
) -> IOKitCallbackContext? {
    guard let pointer else { return nil }
    return Unmanaged<IOKitCallbackContext>.fromOpaque(pointer).takeUnretainedValue()
}

func microDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess else { return }
    callbackContext(context)?.connect(device)
}

func microDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    callbackContext(context)?.disconnect(device)
}

func microInputReportReceived(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    reportType: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard result == kIOReturnSuccess,
        let sender,
        reportType == kIOHIDReportTypeInput,
        reportLength > 0
    else {
        return
    }
    let device = Unmanaged<IOHIDDevice>
        .fromOpaque(sender)
        .takeUnretainedValue()
    callbackContext(context)?.receive(
        from: device,
        reportID: reportID,
        bytes: report,
        count: Int(reportLength)
    )
}
