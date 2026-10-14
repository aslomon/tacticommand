import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroMessageParserTests: XCTestCase {
    func testParsesCompactKeyNotification() throws {
        let data = Data(
            #"{"m":"v.oai.hid","p":{"k":"AG02","act":1,"ag":2}}"#.utf8
        )

        let event = try MicroMessageParser.parse(data)

        XCTAssertEqual(
            event,
            .input(
                MicroInputEvent(
                    control: .agent2,
                    phase: .pressed,
                    rawActivity: 1,
                    agentIndex: 2
                )
            )
        )
    }

    func testParsesStandardKeyNotificationAndRelease() throws {
        let data = Data(
            #"{"jsonrpc":"2.0","method":"v.oai.hid","params":{"k":"ACT12","act":0}}"#.utf8
        )

        let event = try MicroMessageParser.parse(data)

        XCTAssertEqual(
            event,
            .input(
                MicroInputEvent(
                    control: .action12,
                    phase: .released,
                    rawActivity: 0,
                    agentIndex: nil
                )
            )
        )
    }

    func testEncoderRotationIsAPulseForEveryActivityValue() throws {
        for activity in [0, 1, 2, 99] {
            let data = Data(
                "{\"m\":\"v.oai.hid\",\"p\":{\"k\":\"ENC_CW\",\"act\":\(activity)}}".utf8
            )

            let event = try MicroMessageParser.parse(data)

            XCTAssertEqual(
                event,
                .input(
                    MicroInputEvent(
                        control: .encoderClockwise,
                        phase: .pulse,
                        rawActivity: activity,
                        agentIndex: nil
                    )
                )
            )
        }
    }

    func testParsesNormalizedRadialNotification() throws {
        let data = Data(#"{"m":"v.oai.rad","p":{"a":0.75,"d":0.4}}"#.utf8)

        XCTAssertEqual(
            try MicroMessageParser.parse(data),
            .radial(RadialInputEvent(angle: 0.75, distance: 0.4))
        )
    }

    func testParsesDeviceStatusResponse() throws {
        let data = Data(
            #"{"result":{"version":"0.4.1","profile_index":1,"layer_index":4,"battery":82,"is_charging":true},"id":7}"#
                .utf8
        )

        XCTAssertEqual(
            try MicroMessageParser.parse(data),
            .status(
                DeviceStatus(
                    version: "0.4.1",
                    profileIndex: 1,
                    layerIndex: 4,
                    batteryPercentage: 82,
                    isCharging: true
                )
            )
        )
    }

    func testParsesDeviceStatusMethodPayload() throws {
        let data = Data(
            #"{"method":"device.status","params":{"version":"0.5.0","profile_index":0,"layer_index":2,"battery":50,"is_charging":false}}"#
                .utf8
        )

        guard case .status(let status) = try MicroMessageParser.parse(data) else {
            return XCTFail("Expected a status event")
        }
        XCTAssertEqual(status.layerIndex, 2)
        XCTAssertEqual(status.profileIndex, 0)
    }

    func testParsesCorrelatedDeviceStatusResultWithMethod() throws {
        let payloads = [
            #"{"result":{"version":"v0.4.1","profile_index":0,"layer_index":1,"battery":100,"is_charging":false},"id":1,"method":"device.status"}"#,
            #"{"result":{"version":"v0.4.1","profile_index":0,"layer_index":1,"battery":100,"is_charging":false},"id":1,"m":"device.status"}"#,
        ]

        for payload in payloads {
            let data = Data(payload.utf8)

            XCTAssertEqual(
                try MicroMessageParser.parse(data),
                .status(
                    DeviceStatus(
                        version: "v0.4.1",
                        profileIndex: 0,
                        layerIndex: 1,
                        batteryPercentage: 100,
                        isCharging: false
                    )
                )
            )
            XCTAssertEqual(MicroMessageParser.responseIdentifier(data), 1)
        }
    }

    func testTreatsMethodlessAcknowledgementsAsUnhandledReplies() throws {
        let payloads = [
            #"{"result":null,"id":null}"#,
            #"{"result":{"ok":1},"id":null}"#,
        ]

        for payload in payloads {
            XCTAssertEqual(
                try MicroMessageParser.parse(Data(payload.utf8)),
                .unhandled(method: "response")
            )
        }
    }

    func testTreatsMethodlessDeviceErrorEnvelopeAsUnhandledReply() throws {
        let payload = Data(
            #"{"error":{"code":400,"message":"JSON error - EmptyInput"},"id":null}"#.utf8
        )

        XCTAssertEqual(
            try MicroMessageParser.parse(payload),
            .unhandled(method: "response.error")
        )
    }

    func testSurfacesUnknownMethodlessDeviceErrors() {
        let payload = Data(
            #"{"error":{"code":500,"message":"Device failure"},"id":null}"#.utf8
        )

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(
                error as? MicroMessageParserError,
                .deviceError(code: 500, message: "Device failure")
            )
        }
    }

    func testDeviceErrorTakesPrecedenceOverStatusResult() {
        let payload = Data(
            #"{"result":{"version":"0.4.1","battery":82},"error":{"code":500,"message":"Device failure"},"id":1}"#.utf8
        )

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(
                error as? MicroMessageParserError,
                .deviceError(code: 500, message: "Device failure")
            )
        }
    }

    func testDeviceErrorTakesPrecedenceOnMethodfulStatusPayload() {
        let payload = Data(
            #"{"method":"device.status","result":{"version":"0.4.1"},"error":{"code":500,"message":"Device failure"},"id":1}"#
                .utf8
        )

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(
                error as? MicroMessageParserError,
                .deviceError(code: 500, message: "Device failure")
            )
        }
    }

    func testSurfacesCorrelatedEmptyInputDeviceError() {
        let payload = Data(
            #"{"error":{"code":400,"message":"JSON error - EmptyInput"},"id":1}"#.utf8
        )

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(
                error as? MicroMessageParserError,
                .deviceError(code: 400, message: "JSON error - EmptyInput")
            )
        }
    }

    func testRejectsMalformedStatusResultInsteadOfTreatingItAsAcknowledgement() {
        let payload = Data(#"{"result":{"battery":"full"},"id":1}"#.utf8)

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testStillRejectsMethodlessNonResponsePayload() {
        let payload = Data(#"{"id":1}"#.utf8)

        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(error as? MicroMessageParserError, .missingMethod)
        }
    }

    func testRejectsUnknownControlsAndOutOfRangeRadialValues() {
        let unknownControl = Data(
            #"{"m":"v.oai.hid","p":{"k":"ACT99","act":1}}"#.utf8
        )
        let invalidRadial = Data(
            #"{"m":"v.oai.rad","p":{"a":0.5,"d":1.1}}"#.utf8
        )

        XCTAssertThrowsError(try MicroMessageParser.parse(unknownControl))
        XCTAssertThrowsError(try MicroMessageParser.parse(invalidRadial))
    }

    func testBuildsStandardDeviceStatusRequestWithNullParams() throws {
        let request = try MicroCommandBuilder.deviceStatusRequest(identifier: 11)
        let decoded = try JSONDecoder().decode(StatusRequest.self, from: request)

        XCTAssertEqual(decoded.method, "device.status")
        XCTAssertEqual(decoded.identifier, 11)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: request) as? [String: Any])
        XCTAssertTrue(object["params"] is NSNull)
        XCTAssertNil(object["m"])
    }

    func testReadsResponseIdentifierOnlyFromCorrelatableReply() {
        let response = Data(#"{"result":{"version":"0.4.1"},"id":7}"#.utf8)
        let notification = Data(#"{"m":"device.status","p":{"version":"0.4.1"}}"#.utf8)

        XCTAssertEqual(MicroMessageParser.responseIdentifier(response), 7)
        XCTAssertNil(MicroMessageParser.responseIdentifier(notification))
        XCTAssertNil(MicroMessageParser.responseIdentifier(Data("invalid".utf8)))
    }
}

private struct StatusRequest: Decodable {
    let method: String
    let identifier: Int

    enum CodingKeys: String, CodingKey {
        case method
        case identifier = "id"
    }
}
