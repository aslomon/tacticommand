import Foundation
import XCTest

@testable import CreatorMicroCore

final class FirmwareKeymapDocumentTests: XCTestCase {
    static let fixture = Data(
        #"{"activeProfileId":7,"unknown":9007199254740993,"profiles":[{"id":7,"name":"Default","extra":true,"layers":[{"id":0,"name":"Factory","layout":{"keymap":[["A"]]}},{"id":1,"name":"Custom","color":12,"unknown":"keep","layout":{"keymap":[["B"]],"encoders":[],"joystick":{"type":"KEY","sectors":[1],"unknown":true},"buttons":[]}}]}]}"#
            .utf8)

    func testPreparationUsesOneBasedLayerAndPreservesOtherFields() throws {
        let document = try FirmwareKeymapDocument(data: Self.fixture, rawLayer: 2)
        let prepared = try document.preparedCreator()
        let parsed = try FirmwareKeymapDocument(data: prepared, rawLayer: 2)
        XCTAssertTrue(parsed.isCreatorReady)
        XCTAssertEqual(parsed.layer["unknown"], .string("keep"))
        XCTAssertEqual(parsed.value["unknown"], .number(Decimal(string: "9007199254740993")!))
        XCTAssertEqual(parsed.layers[0], document.layers[0])
        XCTAssertEqual(parsed.layer["layout"]?["joystick"]?["unknown"], .bool(true))
    }

    func testRestoreOnlyReplacesTheTargetLayer() throws {
        let original = try FirmwareKeymapDocument(data: Self.fixture, rawLayer: 2)
        let prepared = try FirmwareKeymapDocument(data: original.preparedCreator(), rawLayer: 2)
        let restored = try prepared.replacingLayer(original.layer)
        XCTAssertEqual(try JSONDecoder().decode(MicroJSONValue.self, from: restored), original.value)
    }

    func testZeroBasedOrMissingLayerIsRejected() {
        XCTAssertThrowsError(try FirmwareKeymapDocument(data: Self.fixture, rawLayer: 0))
        XCTAssertThrowsError(try FirmwareKeymapDocument(data: Self.fixture, rawLayer: 3))
    }
}
