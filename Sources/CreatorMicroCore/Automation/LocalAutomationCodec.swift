import CoreFoundation
import Foundation

public struct LocalAutomationCodec: Sendable {
    public init() {}

    public func decodeRequest(
        _ line: Data
    ) -> Result<LocalAutomationRequest, LocalAutomationProtocolFailure> {
        do {
            return .success(try parse(line))
        } catch let failure as LocalAutomationProtocolFailure {
            return .failure(failure)
        } catch {
            return .failure(failure(.invalidRequest, "The request is not valid JSON."))
        }
    }

    public func encode(_ response: LocalAutomationResponse) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(response)
    }

    public func encode(_ request: LocalAutomationRequest) throws -> Data {
        _ = try parseIdentifier(request.id)
        var object: [String: Any] = [
            "version": LocalAutomationProtocol.currentVersion,
            "id": request.id,
        ]
        let wire = wireCommand(request.command)
        object["method"] = wire.method
        if !wire.params.isEmpty { object["params"] = wire.params }
        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    public func decodeResponse(
        _ data: Data
    ) -> Result<LocalAutomationResponse, LocalAutomationProtocolFailure> {
        do {
            guard data.count <= LocalAutomationProtocol.maximumLineBytes else {
                throw failure(.frameTooLarge, "The response exceeds the size limit.")
            }
            let response = try JSONDecoder().decode(LocalAutomationResponse.self, from: data)
            try validate(response)
            return .success(response)
        } catch let failure as LocalAutomationProtocolFailure {
            return .failure(failure)
        } catch {
            return .failure(failure(.invalidRequest, "The response is invalid."))
        }
    }

    private func parse(_ line: Data) throws -> LocalAutomationRequest {
        guard !line.isEmpty else {
            throw failure(.invalidRequest, "The request must not be empty.")
        }
        guard line.count <= LocalAutomationProtocol.maximumLineBytes else {
            throw failure(.frameTooLarge, "The request exceeds the size limit.")
        }
        let value = try JSONSerialization.jsonObject(with: line)
        guard let object = value as? [String: Any] else {
            throw failure(.invalidRequest, "The request must be a JSON object.")
        }
        return try parseObject(object)
    }

    private func parseObject(_ object: [String: Any]) throws -> LocalAutomationRequest {
        let allowed = Set(["version", "id", "method", "params"])
        guard Set(object.keys).isSubset(of: allowed) else {
            throw failure(.invalidRequest, "The request contains an unknown field.")
        }
        let identifier = try parseIdentifier(object["id"])
        try validateVersion(object["version"], requestID: identifier)
        guard let rawMethod = object["method"] as? String,
            let method = Method(rawValue: rawMethod)
        else {
            throw failure(
                .methodNotFound,
                "The requested method does not exist.",
                requestID: identifier
            )
        }
        let command = try parseCommand(method, params: object["params"], requestID: identifier)
        return LocalAutomationRequest(id: identifier, command: command)
    }

    private func parseIdentifier(_ value: Any?) throws -> String {
        guard let identifier = value as? String,
            !identifier.isEmpty,
            identifier.utf8.count <= LocalAutomationProtocol.maximumIdentifierBytes,
            identifier.unicodeScalars.allSatisfy(Self.allowedIdentifierScalars.contains)
        else {
            throw failure(.invalidRequest, "The request identifier is invalid.")
        }
        return identifier
    }

    private func validateVersion(_ value: Any?, requestID: String) throws {
        guard let version = strictInteger(value) else {
            throw failure(.invalidRequest, "The protocol version must be an integer.", requestID: requestID)
        }
        guard version == LocalAutomationProtocol.currentVersion else {
            throw failure(
                .unsupportedVersion,
                "Only local automation protocol version 1 is supported.",
                requestID: requestID
            )
        }
    }

    private func parseCommand(
        _ method: Method,
        params value: Any?,
        requestID: String
    ) throws -> LocalAutomationCommand {
        let params = try parameterObject(value, requestID: requestID)
        switch method {
        case .status:
            try validate(keys: params.keys, expected: [], requestID: requestID)
            return .status
        case .listLayers:
            try validate(keys: params.keys, expected: [], requestID: requestID)
            return .listLayers
        case .setLayer:
            return .setLayer(try parseLayer(params, expected: ["layer"], requestID: requestID))
        case .triggerBinding:
            return try parseTrigger(params, requestID: requestID)
        }
    }

    private func parameterObject(
        _ value: Any?,
        requestID: String
    ) throws -> [String: Any] {
        guard let value else { return [:] }
        guard let params = value as? [String: Any] else {
            throw failure(.invalidParameters, "Parameters must be a JSON object.", requestID: requestID)
        }
        return params
    }

    private func parseTrigger(
        _ params: [String: Any],
        requestID: String
    ) throws -> LocalAutomationCommand {
        try validate(keys: params.keys, expected: ["control", "layer"], requestID: requestID)
        guard let rawControl = params["control"] as? String,
            let control = ControlID(rawValue: rawControl)
        else {
            throw failure(.invalidParameters, "The control is unknown.", requestID: requestID)
        }
        let layer = try parseLayer(params, expected: ["control", "layer"], requestID: requestID)
        return .triggerBinding(control: control, layer: layer)
    }

    private func parseLayer(
        _ params: [String: Any],
        expected: Set<String>,
        requestID: String
    ) throws -> LayerIndex {
        try validate(keys: params.keys, expected: expected, requestID: requestID)
        guard let rawLayer = strictInteger(params["layer"]),
            let layer = LocalAutomationLayerWireID.layer(for: rawLayer)
        else {
            throw failure(.invalidParameters, "The layer must be an integer from 0 through 9.", requestID: requestID)
        }
        return layer
    }

    private func validate(
        keys: Dictionary<String, Any>.Keys,
        expected: Set<String>,
        requestID: String
    ) throws {
        guard Set(keys) == expected else {
            throw failure(.invalidParameters, "The parameters do not match the method schema.", requestID: requestID)
        }
    }

    private func strictInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            Self.integerObjectiveCTypes.contains(String(cString: number.objCType))
        else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite, double.rounded(.towardZero) == double,
            double >= Double(Int.min), double <= Double(Int.max)
        else { return nil }
        return Int(double)
    }

    private func failure(
        _ code: LocalAutomationErrorCode,
        _ message: String,
        requestID: String? = nil
    ) -> LocalAutomationProtocolFailure {
        LocalAutomationProtocolFailure(
            requestID: requestID,
            error: LocalAutomationError(code: code, message: message)
        )
    }

    private func wireCommand(
        _ command: LocalAutomationCommand
    ) -> (method: String, params: [String: Any]) {
        switch command {
        case .status:
            return (Method.status.rawValue, [:])
        case .listLayers:
            return (Method.listLayers.rawValue, [:])
        case .setLayer(let layer):
            return (Method.setLayer.rawValue, ["layer": LocalAutomationLayerWireID.value(for: layer)])
        case .triggerBinding(let control, let layer):
            return (
                Method.triggerBinding.rawValue,
                [
                    "control": control.rawValue,
                    "layer": LocalAutomationLayerWireID.value(for: layer),
                ]
            )
        }
    }

    private func validate(_ response: LocalAutomationResponse) throws {
        guard response.version == LocalAutomationProtocol.currentVersion else {
            throw failure(.unsupportedVersion, "The response protocol version is unsupported.")
        }
        guard (response.result == nil) != (response.error == nil) else {
            throw failure(.invalidRequest, "The response must contain one result or one error.")
        }
    }

    private enum Method: String {
        case status
        case listLayers
        case setLayer
        case triggerBinding
    }

    private static let allowedIdentifierScalars = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    )
    private static let integerObjectiveCTypes: Set<String> = [
        "c", "s", "i", "l", "q", "C", "S", "I", "L", "Q",
    ]
}
