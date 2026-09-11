import CoreFoundation
import CreatorMicroCore
import Foundation
import IOKit.hid

struct MicroDeviceRecord: Codable, Identifiable, Equatable, Hashable, Sendable {
    let identifier: String
    let name: String
    let serialNumber: String?
    let transport: MicroTransportKind

    var id: String { identifier }

    var connectionLabel: String {
        transport == .usb ? "USB" : "Bluetooth"
    }
}

enum MicroDeviceInventoryPresentation {
    static let bluetoothSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension"
    )!

    static func unique(_ devices: [MicroDeviceRecord]) -> [MicroDeviceRecord] {
        var identifiers = Set<String>()
        return devices.filter { identifiers.insert($0.identifier).inserted }
    }

    static func remembering(
        _ observed: [MicroDeviceRecord],
        among known: [MicroDeviceRecord]
    ) -> [MicroDeviceRecord] {
        Array(unique(observed + known).prefix(8))
    }
}

protocol RecentMicroDeviceStoring {
    func load() -> [MicroDeviceRecord]
    func save(_ devices: [MicroDeviceRecord])
}

struct UserDefaultsRecentMicroDeviceStore: RecentMicroDeviceStoring {
    private let defaults: UserDefaults
    private let key = "tacticommand.recentMicroDevices"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [MicroDeviceRecord] {
        guard let data = defaults.data(forKey: key),
            let devices = try? JSONDecoder().decode([MicroDeviceRecord].self, from: data)
        else {
            return []
        }
        return MicroDeviceInventoryPresentation.unique(devices)
    }

    func save(_ devices: [MicroDeviceRecord]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: key)
    }
}

protocol MicroDeviceInventoryReading: Sendable {
    func connectedDevices() -> [MicroDeviceRecord]
}

struct IOKitMicroDeviceInventory: MicroDeviceInventoryReading {
    func connectedDevices() -> [MicroDeviceRecord] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits())
        let criteria = IOKitMicroMatchingPolicy.creatorMicro.managerCriteria
        IOHIDManagerSetDeviceMatching(manager, criteria as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits()) == kIOReturnSuccess else {
            return []
        }
        defer { IOHIDManagerClose(manager, IOOptionBits()) }
        guard let deviceSet = IOHIDManagerCopyDevices(manager) else { return [] }
        return MicroDeviceInventoryPresentation.unique(records(from: deviceSet))
    }

    private func records(from deviceSet: CFSet) -> [MicroDeviceRecord] {
        let count = CFSetGetCount(deviceSet)
        var values = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &values)
        return values.compactMap { value in
            guard let value else { return nil }
            let device = Unmanaged<IOHIDDevice>
                .fromOpaque(value)
                .takeUnretainedValue()
            return record(for: device)
        }
    }

    private func record(for device: IOHIDDevice) -> MicroDeviceRecord? {
        guard let descriptor = IOKitHIDDeviceDescriptorReader.read(device),
            IOKitMicroMatchingPolicy.creatorMicro.matches(descriptor)
        else {
            return nil
        }
        let name = stringProperty(device, key: kIOHIDProductKey) ?? "Creator Micro"
        let serialNumber = stringProperty(device, key: kIOHIDSerialNumberKey)
        let transportValue = stringProperty(device, key: kIOHIDTransportKey)
        let transport = transportValue.flatMap(MicroTransportKind.init(ioKitValue:)) ?? .usb
        let identifier = serialNumber ?? "\(name)-\(transport.rawValue)"
        return MicroDeviceRecord(
            identifier: identifier,
            name: name,
            serialNumber: serialNumber,
            transport: transport
        )
    }

    private func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        return String(describing: value)
    }
}
