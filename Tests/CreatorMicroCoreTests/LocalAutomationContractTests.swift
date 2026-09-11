import Foundation
import XCTest

@testable import CreatorMicroCore

final class LocalAutomationContractTests: XCTestCase {
    private let codec = LocalAutomationCodec()

    func testDecodesEveryVersionOneMethod() throws {
        XCTAssertEqual(try decode(#"{"version":1,"id":"one","method":"status"}"#).command, .status)
        XCTAssertEqual(
            try decode(#"{"version":1,"id":"two","method":"listLayers","params":{}}"#).command,
            .listLayers
        )
        XCTAssertEqual(
            try decode(#"{"version":1,"id":"three","method":"setLayer","params":{"layer":4}}"#).command,
            .setLayer(.meetingControls)
        )
        XCTAssertEqual(
            try decode(
                #"{"version":1,"id":"four","method":"triggerBinding","params":{"control":"ACT10","layer":1}}"#
            ).command,
            .triggerBinding(control: .action10, layer: .desktop)
        )
    }

    func testRejectsUnknownFieldsAndInvalidParameters() {
        assertFailure(
            #"{"version":1,"id":"one","method":"status","extra":true}"#,
            code: .invalidRequest
        )
        assertFailure(
            #"{"version":1,"id":"two","method":"setLayer","params":{"layer":2,"extra":1}}"#,
            code: .invalidParameters
        )
        assertFailure(
            #"{"version":1,"id":"three","method":"triggerBinding","params":{"control":"ACT99","layer":1}}"#,
            code: .invalidParameters
        )
        assertFailure(
            #"{"version":1,"id":"four","method":"setLayer","params":{"layer":true}}"#,
            code: .invalidParameters
        )
        assertFailure(
            #"{"version":1,"id":"five","method":"setLayer","params":{"layer":1.0}}"#,
            code: .invalidParameters
        )
    }

    func testRejectsUnsupportedVersionsMethodsAndIdentifiers() {
        assertFailure(
            #"{"version":2,"id":"one","method":"status"}"#,
            code: .unsupportedVersion
        )
        assertFailure(
            #"{"version":1,"id":"two","method":"eraseEverything"}"#,
            code: .methodNotFound
        )
        assertFailure(
            #"{"version":1,"id":"bad id","method":"status"}"#,
            code: .invalidRequest
        )
    }

    func testRejectsOversizedOrNonObjectInputBeforeDecoding() {
        let oversized = Data(repeating: 0x20, count: LocalAutomationProtocol.maximumLineBytes + 1)

        assertFailure(oversized, code: .frameTooLarge)
        assertFailure(Data("[]".utf8), code: .invalidRequest)
        assertFailure(Data(), code: .invalidRequest)
    }

    func testEncodesStableSuccessAndErrorEnvelopes() throws {
        let success = LocalAutomationResponse.success(
            id: "layers",
            result: .layers([
                LocalAutomationLayer(index: .codex, name: "Codex"),
                LocalAutomationLayer(index: .desktop, name: "Desktop"),
            ])
        )
        let error = LocalAutomationResponse.failure(
            id: "blocked",
            error: LocalAutomationError(code: .forbiddenAction, message: "Blocked")
        )

        let successObject = try object(codec.encode(success))
        let errorObject = try object(codec.encode(error))

        XCTAssertEqual(successObject["version"] as? Int, 1)
        XCTAssertEqual(successObject["id"] as? String, "layers")
        XCTAssertNil(successObject["error"])
        XCTAssertEqual(errorObject["id"] as? String, "blocked")
        XCTAssertNil(errorObject["result"])
        let payload = try XCTUnwrap(errorObject["error"] as? [String: Any])
        XCTAssertEqual(payload["code"] as? String, "forbidden_action")
    }

    func testEncodesRequestsUsingTheSameStrictVersionOneContract() throws {
        let request = LocalAutomationRequest(
            id: "intent-1",
            command: .triggerBinding(control: .action12, layer: .desktop)
        )

        let payload = try object(codec.encode(request))

        XCTAssertEqual(payload["version"] as? Int, 1)
        XCTAssertEqual(payload["id"] as? String, "intent-1")
        XCTAssertEqual(payload["method"] as? String, "triggerBinding")
        let params = try XCTUnwrap(payload["params"] as? [String: Any])
        XCTAssertEqual(params["control"] as? String, "ACT12")
        XCTAssertEqual(params["layer"] as? Int, 1)
    }

    func testVersionOneLayerIdentifiersPreserveLegacySemanticsAndExtendSafely() throws {
        let expectedLayers: [LayerIndex] = [
            .codexCLI,
            .desktop,
            .agentFocus,
            .windowManagement,
            .meetingControls,
            .snippetCommands,
            .claudeCodeCLI,
            .claudeApp,
            .codexApp,
            .cursor,
        ]
        for (wireID, expectedLayer) in expectedLayers.enumerated() {
            let request = try decode(
                #"{"version":1,"id":"layer","method":"setLayer","params":{"layer":\#(wireID)}}"#
            )
            XCTAssertEqual(request.command, .setLayer(expectedLayer))
            let encoded = try object(
                codec.encode(LocalAutomationRequest(id: "layer", command: .setLayer(expectedLayer)))
            )
            let params = try XCTUnwrap(encoded["params"] as? [String: Any])
            XCTAssertEqual(params["layer"] as? Int, wireID)
        }
    }

    func testDecodesItsOwnSuccessAndFailureResponses() throws {
        let success = LocalAutomationResponse.success(
            id: "status",
            result: .status(
                LocalAutomationStatus(
                    activeLayer: .desktop,
                    isReady: true,
                    connection: .connected
                )
            )
        )
        let failure = LocalAutomationResponse.failure(
            id: nil,
            error: LocalAutomationError(code: .invalidRequest, message: "Invalid")
        )

        XCTAssertEqual(try codec.decodeResponse(codec.encode(success)).get(), success)
        XCTAssertEqual(try codec.decodeResponse(codec.encode(failure)).get(), failure)
    }

    func testResponseLayerIdentifiersUseTheSameStableSemanticMapping() throws {
        let response = LocalAutomationResponse.success(
            id: "layers",
            result: .layers([
                LocalAutomationLayer(index: .agentFocus, name: "Agent Focus"),
                LocalAutomationLayer(index: .claudeCodeCLI, name: "Claude Code CLI"),
                LocalAutomationLayer(index: .cursor, name: "Cursor"),
            ])
        )

        let payload = try object(codec.encode(response))
        let result = try XCTUnwrap(payload["result"] as? [String: Any])
        let layers = try XCTUnwrap(result["layers"] as? [[String: Any]])

        XCTAssertEqual(layers.compactMap { $0["index"] as? Int }, [2, 6, 9])
        XCTAssertEqual(try codec.decodeResponse(codec.encode(response)).get(), response)
    }

    private func decode(_ json: String) throws -> LocalAutomationRequest {
        try decode(Data(json.utf8))
    }

    private func decode(_ data: Data) throws -> LocalAutomationRequest {
        switch codec.decodeRequest(data) {
        case .success(let request): return request
        case .failure(let error): throw error
        }
    }

    private func assertFailure(
        _ json: String,
        code: LocalAutomationErrorCode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertFailure(Data(json.utf8), code: code, file: file, line: line)
    }

    private func assertFailure(
        _ data: Data,
        code: LocalAutomationErrorCode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = codec.decodeRequest(data) else {
            return XCTFail("Expected decoding to fail", file: file, line: line)
        }
        XCTAssertEqual(error.error.code, code, file: file, line: line)
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
}
