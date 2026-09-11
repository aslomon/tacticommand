import CreatorMicroCore
import Foundation
import IOKit.hid

struct HIDUsagePair: Equatable, Hashable, Sendable {
    let page: Int
    let usage: Int
}

struct HIDDeviceDescriptor: Equatable, Sendable {
    let vendorIdentifier: Int
    let productIdentifier: Int
    let usagePairs: Set<HIDUsagePair>
}

struct IOKitMicroMatchingPolicy: Sendable {
    static let creatorMicro = IOKitMicroMatchingPolicy(
        vendorIdentifier: MicroProtocolConstants.vendorIdentifier,
        productIdentifier: MicroProtocolConstants.productIdentifier,
        requiredUsagePair: HIDUsagePair(
            page: MicroProtocolConstants.vendorUsagePage,
            usage: 0x0001
        )
    )

    let vendorIdentifier: Int
    let productIdentifier: Int
    let requiredUsagePair: HIDUsagePair

    var managerCriteria: [String: Int] {
        [
            kIOHIDVendorIDKey: vendorIdentifier,
            kIOHIDProductIDKey: productIdentifier,
        ]
    }

    func matches(_ descriptor: HIDDeviceDescriptor) -> Bool {
        descriptor.vendorIdentifier == vendorIdentifier
            && descriptor.productIdentifier == productIdentifier
            && descriptor.usagePairs.contains(requiredUsagePair)
    }
}

enum IOKitHIDDeviceDescriptorReader {
    static func read(_ device: IOHIDDevice) -> HIDDeviceDescriptor? {
        makeDescriptor(
            vendorIdentifier: property(device, key: kIOHIDVendorIDKey),
            productIdentifier: property(device, key: kIOHIDProductIDKey),
            usagePairs: property(device, key: kIOHIDDeviceUsagePairsKey)
        )
    }

    static func makeDescriptor(
        vendorIdentifier: Any?,
        productIdentifier: Any?,
        usagePairs: Any?
    ) -> HIDDeviceDescriptor? {
        guard let vendorIdentifier = integer(from: vendorIdentifier),
            let productIdentifier = integer(from: productIdentifier)
        else {
            return nil
        }
        return HIDDeviceDescriptor(
            vendorIdentifier: vendorIdentifier,
            productIdentifier: productIdentifier,
            usagePairs: self.usagePairs(from: usagePairs)
        )
    }

    static func usagePairs(from property: Any?) -> Set<HIDUsagePair> {
        guard let pairs = property as? [[String: Any]] else { return [] }
        return Set(
            pairs.compactMap { pair in
                guard let page = integer(from: pair[kIOHIDDeviceUsagePageKey]),
                    let usage = integer(from: pair[kIOHIDDeviceUsageKey])
                else {
                    return nil
                }
                return HIDUsagePair(page: page, usage: usage)
            })
    }

    private static func property(
        _ device: IOHIDDevice,
        key: String
    ) -> Any? {
        IOHIDDeviceGetProperty(device, key as CFString)
    }

    private static func integer(from property: Any?) -> Int? {
        (property as? NSNumber)?.intValue
    }
}
