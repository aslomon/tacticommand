import XCTest

@testable import CreatorMicroCore

final class DeviceCapabilityProfileTests: XCTestCase {
    func testCreatorPIDsResolveThirteenIndependentlyLitKeys() {
        for pid in [0x8297, 0x8298] {
            let profile = DeviceCapabilityProfile(productIdentifier: pid)
            XCTAssertEqual(profile.model, .creator13)
            XCTAssertEqual(profile.independentlyLitKeyCount, 13)
            XCTAssertTrue(profile.supportsIndependentActionKeyLighting)
        }
    }

    func testCodexPIDResolvesSixIndependentlyLitKeys() {
        let profile = DeviceCapabilityProfile(productIdentifier: 0x8360)
        XCTAssertEqual(profile.model, .codex6)
        XCTAssertEqual(profile.independentlyLitKeyCount, 6)
        XCTAssertFalse(profile.supportsIndependentActionKeyLighting)
    }

    func testUnknownPIDFallsBackConservativelyAndNeverClaimsCreatorScene() {
        for pid in [nil, 0x1234] {
            let profile = DeviceCapabilityProfile(productIdentifier: pid)
            XCTAssertEqual(profile.model, .unknown)
            XCTAssertEqual(profile.independentlyLitKeyCount, 6)
            XCTAssertFalse(profile.supportsIndependentActionKeyLighting)
            XCTAssertNotEqual(profile.model, .creator13)
        }
    }

    func testOnlyCreatorExposesAWideKeyPairForTenAndEleven() {
        let creator = DeviceCapabilityProfile(productIdentifier: 0x8298)
        let codex = DeviceCapabilityProfile(productIdentifier: 0x8360)

        XCTAssertEqual(creator.wideKeyPair, [.action10, .action11])
        XCTAssertNil(codex.wideKeyPair)
    }

    func testIndependentlyLitControlsAreBoundedByCapability() {
        let creator = DeviceCapabilityProfile(productIdentifier: 0x8298)
        let codex = DeviceCapabilityProfile(productIdentifier: 0x8360)

        XCTAssertEqual(creator.independentlyLitControls.count, 13)
        XCTAssertTrue(creator.independentlyLitControls.contains(.action12))
        XCTAssertEqual(codex.independentlyLitControls.count, 6)
        XCTAssertFalse(codex.independentlyLitControls.contains(.action6))
    }

    func testTopRowMatchesObservedCreatorInputWithAgentZeroOnTheLeft() {
        for pid in [nil, 0x8297, 0x8298, 0x8360, 0x1234] {
            let profile = DeviceCapabilityProfile(productIdentifier: pid)
            XCTAssertEqual(profile.topRowOrdering, .leftToRight)
        }
    }

    func testTopRowGeometryDoesNotRemapFirmwareLightingSlots() {
        for pid in [0x8297, 0x8298, 0x8360] {
            let profile = DeviceCapabilityProfile(productIdentifier: pid)
            XCTAssertEqual(Array(profile.independentlyLitControls.prefix(2)), [.agent0, .agent1])
        }
    }
}
