import IOKit.hid
import XCTest

@testable import CreatorMicroControl

final class IOKitMicroMatchingPolicyTests: XCTestCase {
    func testManagerCriteriaUseDeviceIdentityWithoutPrimaryCollection() {
        let criteria = IOKitMicroMatchingPolicy.creatorMicro.managerCriteria

        XCTAssertEqual(criteria[kIOHIDVendorIDKey], 0x303A)
        XCTAssertEqual(criteria[kIOHIDProductIDKey], 0x8360)
        XCTAssertNil(criteria[kIOHIDDeviceUsagePageKey])
        XCTAssertNil(criteria[kIOHIDPrimaryUsagePageKey])
    }

    func testKeyboardPrimaryDeviceWithVendorCollectionMatches() {
        let device = descriptor(usagePairs: [
            HIDUsagePair(page: 0x0001, usage: 0x0006),
            HIDUsagePair(page: 0x000C, usage: 0x0001),
            HIDUsagePair(page: 0xFF00, usage: 0x0001),
        ])

        XCTAssertTrue(IOKitMicroMatchingPolicy.creatorMicro.matches(device))
    }

    func testIdentityMatchWithoutVendorCollectionIsRejected() {
        let keyboardOnly = descriptor(usagePairs: [
            HIDUsagePair(page: 0x0001, usage: 0x0006),
            HIDUsagePair(page: 0x000C, usage: 0x0001),
        ])

        XCTAssertFalse(IOKitMicroMatchingPolicy.creatorMicro.matches(keyboardOnly))
    }

    func testVendorPageWithWrongUsageIsRejected() {
        let differentVendorCollection = descriptor(usagePairs: [
            HIDUsagePair(page: 0xFF00, usage: 0x0002)
        ])

        XCTAssertFalse(
            IOKitMicroMatchingPolicy.creatorMicro.matches(differentVendorCollection)
        )
    }

    func testUsagePageCannotOverrideWrongDeviceIdentity() {
        let wrongVendor = HIDDeviceDescriptor(
            vendorIdentifier: 0xFFFF,
            productIdentifier: 0x8360,
            usagePairs: [HIDUsagePair(page: 0xFF00, usage: 0x0001)]
        )

        XCTAssertFalse(IOKitMicroMatchingPolicy.creatorMicro.matches(wrongVendor))
    }

    func testUsagePairReaderIncludesEveryTopLevelCollection() {
        let usagePairs: NSArray = [
            NSDictionary(dictionary: [
                kIOHIDDeviceUsagePageKey: NSNumber(value: 0x0001),
                kIOHIDDeviceUsageKey: NSNumber(value: 0x0006),
            ]),
            NSDictionary(dictionary: [
                kIOHIDDeviceUsagePageKey: NSNumber(value: 0xFF00),
                kIOHIDDeviceUsageKey: NSNumber(value: 0x0001),
            ]),
        ]

        let pairs = IOKitHIDDeviceDescriptorReader.usagePairs(from: usagePairs)

        XCTAssertEqual(
            pairs,
            [
                HIDUsagePair(page: 0x0001, usage: 0x0006),
                HIDUsagePair(page: 0xFF00, usage: 0x0001),
            ])
    }

    func testUsagePairReaderRejectsMalformedCollections() {
        let incomplete: NSArray = [
            NSDictionary(dictionary: [kIOHIDDeviceUsageKey: 1])
        ]

        XCTAssertTrue(
            IOKitHIDDeviceDescriptorReader.usagePairs(from: incomplete).isEmpty
        )
        XCTAssertTrue(
            IOKitHIDDeviceDescriptorReader.usagePairs(
                from: "not-a-usage-pair-array"
            ).isEmpty
        )
    }

    func testDescriptorReaderBridgesRegistryProperties() {
        let descriptor = IOKitHIDDeviceDescriptorReader.makeDescriptor(
            vendorIdentifier: NSNumber(value: 0x303A),
            productIdentifier: NSNumber(value: 0x8360),
            usagePairs: vendorUsagePairs()
        )

        XCTAssertEqual(
            descriptor,
            self.descriptor(usagePairs: [
                HIDUsagePair(page: 0x0001, usage: 0x0006),
                HIDUsagePair(page: 0xFF00, usage: 0x0001),
            ]))
    }

    func testDescriptorReaderRejectsMissingIdentity() {
        XCTAssertNil(
            IOKitHIDDeviceDescriptorReader.makeDescriptor(
                vendorIdentifier: nil,
                productIdentifier: NSNumber(value: 0x8360),
                usagePairs: vendorUsagePairs()
            ))
    }

    private func descriptor(usagePairs: Set<HIDUsagePair>) -> HIDDeviceDescriptor {
        HIDDeviceDescriptor(
            vendorIdentifier: 0x303A,
            productIdentifier: 0x8360,
            usagePairs: usagePairs
        )
    }

    private func vendorUsagePairs() -> NSArray {
        [
            NSDictionary(dictionary: [
                kIOHIDDeviceUsagePageKey: NSNumber(value: 0x0001),
                kIOHIDDeviceUsageKey: NSNumber(value: 0x0006),
            ]),
            NSDictionary(dictionary: [
                kIOHIDDeviceUsagePageKey: NSNumber(value: 0xFF00),
                kIOHIDDeviceUsageKey: NSNumber(value: 0x0001),
            ]),
        ]
    }
}
