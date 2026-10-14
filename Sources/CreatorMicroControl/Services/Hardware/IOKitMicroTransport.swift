import CoreFoundation
import CreatorMicroCore
import Dispatch
import Foundation
import IOKit.hid

struct IOKitMicroTransportConnector: MicroTransportConnector {
    private let discoveryTimeout: Duration

    init(discoveryTimeout: Duration = .milliseconds(750)) {
        self.discoveryTimeout = discoveryTimeout
    }

    func connect() async throws -> any MicroTransport {
        let transport = try IOKitMicroTransport.open()
        do {
            try await transport.waitUntilConnected(timeout: discoveryTimeout)
            return transport
        } catch {
            await transport.close()
            throw error
        }
    }
}

final class IOKitMicroTransport: @unchecked Sendable, MicroTransport {
    var kind: MicroTransportKind {
        context.transportKind ?? .usb
    }

    var productIdentifier: Int? {
        context.productIdentifier
    }

    var incomingReports: AsyncStream<Data> {
        context.incomingReports
    }

    private let lifetime: IOKitManagerLifetime
    private let context: IOKitCallbackContext

    private init(
        lifetime: IOKitManagerLifetime,
        context: IOKitCallbackContext
    ) {
        self.lifetime = lifetime
        self.context = context
    }

    static func open() throws -> IOKitMicroTransport {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits())
        let lifetime = IOKitManagerLifetime(manager: manager)
        let context = IOKitCallbackContext()
        configureMatching(manager)
        var startup = IOKitManagerStartup()
        let openResult = startup.run(
            open: { IOHIDManagerOpen(manager, IOOptionBits()) },
            configureDispatch: {
                IOHIDManagerSetDispatchQueue(manager, lifetime.queue)
                registerCallbacks(lifetime: lifetime, context: context)
            },
            activate: { IOHIDManagerActivate(manager) }
        )
        guard openResult == kIOReturnSuccess else {
            throw MicroConnectionError.outputReportFailed(
                code: openResult
            )
        }
        enumerateCurrentDevices(manager, context: context)
        return IOKitMicroTransport(lifetime: lifetime, context: context)
    }

    func write(_ report: Data) async throws {
        try context.write(report)
    }

    func close() async {
        if context.beginCancellation() {
            _ = IOHIDManagerClose(lifetime.manager, IOOptionBits())
            IOHIDManagerCancel(lifetime.manager)
        }
        await context.waitForCancellation()
    }

    func waitUntilConnected(timeout: Duration) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try Task.checkCancellation()
            if context.transportKind != nil { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw MicroConnectionError.deviceNotFound
    }

    private static func configureMatching(_ manager: IOHIDManager) {
        let matching = IOKitMicroMatchingPolicy.creatorMicro.managerCriteria
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
    }

    private static func registerCallbacks(
        lifetime: IOKitManagerLifetime,
        context: IOKitCallbackContext
    ) {
        let retained = Unmanaged.passRetained(context).toOpaque()
        let pointer = SendableOpaquePointer(rawValue: retained)
        IOHIDManagerRegisterDeviceMatchingCallback(
            lifetime.manager,
            microDeviceMatched,
            retained
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            lifetime.manager,
            microDeviceRemoved,
            retained
        )
        IOHIDManagerRegisterInputReportCallback(
            lifetime.manager,
            microInputReportReceived,
            retained
        )
        IOHIDManagerSetCancelHandler(lifetime.manager) { [lifetime, pointer] in
            let retainedContext = Unmanaged<IOKitCallbackContext>
                .fromOpaque(pointer.rawValue)
                .takeRetainedValue()
            retainedContext.finishCancellation()
            _ = lifetime
        }
    }

    private static func enumerateCurrentDevices(
        _ manager: IOHIDManager,
        context: IOKitCallbackContext
    ) {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) else { return }
        let count = CFSetGetCount(deviceSet)
        var values = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &values)
        for value in values {
            guard let value else { continue }
            let device = Unmanaged<IOHIDDevice>
                .fromOpaque(value)
                .takeUnretainedValue()
            context.connect(device)
        }
    }

    deinit {
        if context.beginCancellation() {
            _ = IOHIDManagerClose(lifetime.manager, IOOptionBits())
            IOHIDManagerCancel(lifetime.manager)
        }
    }
}
