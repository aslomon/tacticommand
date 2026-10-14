import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroMessageParserCompatibilityTests: XCTestCase {
    func testParsesCreatorActionAndConfiguredEncoderAliases() throws {
        let aliases: [(String, ControlID)] = [
            ("AG06", .action6), ("AG07", .action7), ("AG08", .action8),
            ("AG09", .action9), ("AG10", .action10), ("AG11", .action11),
            ("AG12", .action12), ("AG13", .encoderClockwise),
            ("AG14", .encoderCounterClockwise), ("AG15", .encoderPress),
        ]
        for (key, control) in aliases {
            let payload = Data("{\"m\":\"v.oai.hid\",\"p\":{\"k\":\"\(key)\",\"act\":1}}".utf8)
            XCTAssertEqual(
                try MicroMessageParser.parse(payload),
                .input(
                    MicroInputEvent(
                        control: control,
                        phase: .pressed,
                        rawActivity: 1, agentIndex: nil))
            )
        }
    }

    func testCreatorEncoderAliasReleaseDoesNotRepulseUnlikeNativeRotation() throws {
        for key in ["AG13", "AG14"] {
            let payload = Data("{\"m\":\"v.oai.hid\",\"p\":{\"k\":\"\(key)\",\"act\":0}}".utf8)
            guard case .input(let event) = try MicroMessageParser.parse(payload) else {
                return XCTFail("Expected an input event for \(key)")
            }
            XCTAssertEqual(event.phase, .released)
        }
    }

    func testCreatorEncoderAliasExecutesOnceAcrossPressAndRelease() throws {
        let layer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.encoderClockwise: .volume(.increase)]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .separate)
        let press = try MicroMessageParser.parse(
            Data(#"{"m":"v.oai.hid","p":{"k":"AG13","act":1}}"#.utf8))
        let release = try MicroMessageParser.parse(
            Data(#"{"m":"v.oai.hid","p":{"k":"AG13","act":0}}"#.utf8))
        guard case .input(let pressEvent) = press, case .input(let releaseEvent) = release else {
            return XCTFail("Expected input events")
        }

        let pressedActions = router.route(pressEvent, on: layer)
        let releasedActions = router.route(releaseEvent, on: layer)

        XCTAssertEqual(pressedActions, [.init(action: .volume(.increase), phase: .pressed)])
        XCTAssertEqual(releasedActions, [.init(action: .volume(.increase), phase: .released)])
    }

    func testParsesCreatorRadialNotification() throws {
        let payload = Data(#"{"method":"kb.radial","params":{"a":0.25,"d":0.8,"l":1,"p":0,"o":1}}"#.utf8)
        XCTAssertEqual(
            try MicroMessageParser.parse(payload),
            .radial(RadialInputEvent(angle: 0.25, distance: 0.8)))
    }

    func testCreatorRadialHideReleasesStickEvenWithStaleDistance() throws {
        let payload = Data(#"{"m":"kb.radial","p":{"a":0.25,"d":0.8,"o":0}}"#.utf8)
        XCTAssertEqual(
            try MicroMessageParser.parse(payload),
            .radial(RadialInputEvent(angle: 0, distance: 0)))
    }

    func testCreatorHideDoesNotRequireCoordinatesOrValidateStaleValues() throws {
        for params in [#"{"o":0}"#, #"{"o":0,"a":99,"d":-1}"#] {
            let payload = Data("{\"m\":\"kb.radial\",\"p\":\(params)}".utf8)
            XCTAssertEqual(try MicroMessageParser.parse(payload), .radial(RadialInputEvent(angle: 0, distance: 0)))
        }
    }

    func testMethodfulUncorrelatedEmptyInputIsBenign() throws {
        let payload = Data(
            #"{"method":"device.status","error":{"code":400,"message":"JSON error - EmptyInput"},"id":null}"#.utf8)
        XCTAssertEqual(try MicroMessageParser.parse(payload), .unhandled(method: "response.error"))
    }

    func testSurfacesMethodfulLightingErrors() {
        let payload = Data(
            #"{"method":"v.oai.rgbcfg","error":{"code":404,"message":"Method not found"},"id":null}"#.utf8)
        XCTAssertThrowsError(try MicroMessageParser.parse(payload)) { error in
            XCTAssertEqual(
                error as? MicroMessageParserError,
                .deviceError(code: 404, message: "Method not found"))
        }
    }
}
