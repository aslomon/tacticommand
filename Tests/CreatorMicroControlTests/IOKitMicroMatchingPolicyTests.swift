import IOKit.hid
import XCTest

@testable import CreatorMicroControl

final class IOKitMicroMatchingPolicyTests: XCTestCase {
    func testManagerCriteriaIncludeSupportedDeviceIdentitiesWithoutPrimaryCollection() {
        let criteria = IOKitMicroMatchingPolicy.creatorMicro.managerCriteria

        XCTAssertEqual(criteria.count, 3)
        XCTAssertTrue(
            criteria.contains {
                $0[kIOHIDVendorIDKey] == 0x303A && $0[kIOHIDProductIDKey] == 0x8297
            })
        XCTAssertTrue(
            criteria.contains {
                $0[kIOHIDVendorIDKey] == 0x303A
                    && $0[kIOHIDProductIDKey] == 0x8360
            })
        XCTAssertTrue(
            criteria.contains {
                $0[kIOHIDVendorIDKey] == 0x303A
                    && $0[kIOHIDProductIDKey] == 0x8298
            })
        XCTAssertTrue(criteria.allSatisfy { $0[kIOHIDDeviceUsagePageKey] == nil })
        XCTAssertTrue(criteria.allSatisfy { $0[kIOHIDPrimaryUsagePageKey] == nil })
    }

    func testKeyboardPrimaryDeviceWithVendorCollectionMatches() {
        let device = descriptor(usagePairs: [
            HIDUsagePair(page: 0x0001, usage: 0x0006),
            HIDUsagePair(page: 0x000C, usage: 0x0001),
            HIDUsagePair(page: 0xFF00, usage: 0x0001),
        ])

        XCTAssertTrue(IOKitMicroMatchingPolicy.creatorMicro.matches(device))
    }

    func testCreatorMicroVariantMatchesIndependentlyOfTransport() {
        let device = descriptor(
            productIdentifier: 0x8298,
            usagePairs: [
                HIDUsagePair(page: 0x0001, usage: 0x0006),
                HIDUsagePair(page: 0xFF00, usage: 0x0001),
            ])

        XCTAssertTrue(IOKitMicroMatchingPolicy.creatorMicro.matches(device))
    }

    func testUnsupportedProductVariantIsRejected() {
        let device = descriptor(
            productIdentifier: 0x8299,
            usagePairs: [HIDUsagePair(page: 0xFF00, usage: 0x0001)])

        XCTAssertFalse(IOKitMicroMatchingPolicy.creatorMicro.matches(device))
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

    private func descriptor(
        productIdentifier: Int = 0x8360,
        usagePairs: Set<HIDUsagePair>
    ) -> HIDDeviceDescriptor {
        HIDDeviceDescriptor(
            vendorIdentifier: 0x303A,
            productIdentifier: productIdentifier,
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
