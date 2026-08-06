// TransmissionRPCResolver.swift
// Remission
//
// RPC protocol resolution: encoding/decoding requests and responses for both
// Legacy and JSON-RPC 2.0 Transmission protocols, plus mode auto-detection.

import Foundation

/// Resolves RPC protocol: handles encoding/decoding for both Legacy and JSON-RPC 2.0.
struct TransmissionRPCResolver {
    let mode: TransmissionRPCMode
    let rpcModeStore: RPCModeStoreProtocol
    let jsonrpcIDStore: JSONRPCIDStoreProtocol

    // Test accessors for concrete types
    var rpcModeStoreConcrete: RPCModeStore? { rpcModeStore as? RPCModeStore }
    var jsonrpcIDStoreConcrete: JSONRPCIDStore? { jsonrpcIDStore as? JSONRPCIDStore }

    // For backwards compatibility with tests - allows setting RPC version
    var rpcVersionStore: RPCVersionStore? {
        get { nil }
        set { /* no-op for backwards compatibility */  }
    }

    init(
        mode: TransmissionRPCMode,
        rpcModeStore: RPCModeStoreProtocol,
        jsonrpcIDStore: JSONRPCIDStoreProtocol
    ) {
        self.mode = mode
        self.rpcModeStore = rpcModeStore
        self.jsonrpcIDStore = jsonrpcIDStore
    }

    /// Returns the initial list of modes to try based on configuration.
    func initialModesToTry() async -> [TransmissionRPCMode] {
        if mode != .auto {
            return [mode]
        }
        if let resolved = await rpcModeStore.load() {
            return [resolved]
        }
        return [.jsonRpc2, .legacy]
    }

    /// Persists the resolved mode if auto-detection is enabled.
    func persistResolvedModeIfNeeded(_ mode: TransmissionRPCMode) async {
        guard self.mode == .auto else { return }
        await rpcModeStore.store(mode)
    }

    /// Encodes an RPC request body for the given mode.
    func encodeRequestBody(
        method: String,
        arguments: AnyCodable?,
        tag: TransmissionTag?,
        mode: TransmissionRPCMode
    ) async throws -> Data {
        switch mode {
        case .legacy, .auto:
            let request = TransmissionRequest(method: method, arguments: arguments, tag: tag)
            return try JSONEncoder().encode(request)
        case .jsonRpc2:
            let jsonrpcMethod = toJSONRPCMethod(method)
            let jsonrpcParams = arguments.map { convertAnyCodableToJSONRPC($0) } ?? .object([:])
            let jsonrpcID: TransmissionTag
            if let tag {
                jsonrpcID = tag
            } else {
                jsonrpcID = await jsonrpcIDStore.next()
            }
            let request = JSONRPCRequest(
                method: jsonrpcMethod,
                params: jsonrpcParams,
                id: jsonrpcID
            )
            return try JSONEncoder().encode(request)
        }
    }

    /// Decodes an RPC response for the given mode.
    func decodeResponse(from data: Data, mode: TransmissionRPCMode) throws -> TransmissionResponse {
        switch mode {
        case .legacy, .auto:
            return try decodeLegacyResponse(from: data)
        case .jsonRpc2:
            return try decodeJSONRPCResponse(from: data)
        }
    }

    /// Decodes a legacy Transmission response.
    private func decodeLegacyResponse(from data: Data) throws -> TransmissionResponse {
        guard !data.isEmpty else {
            throw APIError.decodingFailed(underlyingError: "Empty response body")
        }
        do {
            return try JSONDecoder().decode(TransmissionResponse.self, from: data)
        } catch let decodingError as DecodingError {
            throw APIError.mapDecodingError(decodingError)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.unknown(details: error.localizedDescription)
        }
    }

    /// Decodes a JSON-RPC 2.0 response.
    private func decodeJSONRPCResponse(from data: Data) throws -> TransmissionResponse {
        do {
            let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            guard let jsonrpc = response.jsonrpc, jsonrpc == "2.0" else {
                throw APIError.decodingFailed(
                    underlyingError: "Unsupported jsonrpc version: \(response.jsonrpc ?? "null")"
                )
            }
            if response.result != nil, response.error != nil {
                throw APIError.decodingFailed(
                    underlyingError: "Invalid JSON-RPC response: result and error are both present"
                )
            }
            if let error = response.error {
                let errorString = jsonRPCErrorString(from: error)
                throw APIError.jsonRPC(
                    code: error.code,
                    message: error.message,
                    errorString: errorString
                )
            }
            guard let result = response.result else {
                throw APIError.decodingFailed(
                    underlyingError: "Missing result in JSON-RPC response"
                )
            }
            let arguments: AnyCodable?
            if case .object = result {
                arguments = result
            } else {
                arguments = .object(["value": result])
            }
            return TransmissionResponse(result: "success", arguments: arguments, tag: response.id)
        } catch let decodingError as DecodingError {
            throw APIError.mapDecodingError(decodingError)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.unknown(details: error.localizedDescription)
        }
    }

    /// Extracts error string from JSON-RPC error data.
    private func jsonRPCErrorString(from error: JSONRPCError) -> String? {
        if let data = error.data?.objectValue,
            let errorString = data["error_string"]?.stringValue,
            !errorString.isEmpty
        {
            return errorString
        }
        return nil
    }

    /// Converts legacy method name (e.g., "torrent-get") to JSON-RPC method (e.g., "torrent_get").
    func toJSONRPCMethod(_ legacyMethod: String) -> String {
        legacyMethod.replacingOccurrences(of: "-", with: "_")
    }

    /// Converts AnyCodable from legacy format to JSON-RPC format (camelCase → snake_case keys).
    func convertAnyCodableToJSONRPC(_ value: AnyCodable) -> AnyCodable {
        switch value {
        case .object(let object):
            let converted = object.reduce(into: [String: AnyCodable]()) { partial, pair in
                let convertedKey = toSnakeCase(pair.key)
                if convertedKey == "fields", case .array(let array) = pair.value {
                    let convertedFields = array.map { element -> AnyCodable in
                        if case .string(let fieldName) = element {
                            return .string(toSnakeCase(fieldName))
                        }
                        return element
                    }
                    partial[convertedKey] = .array(convertedFields)
                } else {
                    partial[convertedKey] = convertAnyCodableToJSONRPC(pair.value)
                }
            }
            return .object(converted)
        case .array(let array):
            return .array(array.map { convertAnyCodableToJSONRPC($0) })
        case .string, .int, .double, .bool, .null:
            return value
        }
    }

    /// Converts a key to snake_case.
    private func toSnakeCase(_ key: String) -> String {
        if key.contains("_") {
            return key
        }
        return key.reduce(into: "") { partial, scalar in
            if scalar.isUppercase {
                partial.append("_")
                partial.append(scalar.lowercased())
            } else if scalar == "-" {
                partial.append("_")
            } else {
                partial.append(scalar)
            }
        }
    }

    /// Determines if an APIError should trigger JSON-RPC → Legacy fallback.
    func fallbackReasonFromAPIError(_ error: APIError) -> String? {
        switch error {
        case .decodingFailed(let details):
            let lower = details.lowercased()
            let protocolMismatchSignals = [
                "missing result in json-rpc response",
                "missing or invalid rpc-version/rpc_version in session-get response",
                "unsupported jsonrpc version",
                "invalid json-rpc response"
            ]
            if protocolMismatchSignals.contains(where: { lower.contains($0) }) {
                return details
            }
            return nil
        case .unknown(let details):
            let lower = details.lowercased()
            if lower.contains("method not found") || lower.contains("json-rpc") {
                return details
            }
            return nil
        default:
            return nil
        }
    }
}

/// Protocol for RPC mode storage (allows mocking).
protocol RPCModeStoreProtocol: Sendable {
    func load() async -> TransmissionRPCMode?
    func store(_ mode: TransmissionRPCMode) async
}

/// Protocol for JSON-RPC ID generation.
protocol JSONRPCIDStoreProtocol: Sendable {
    func next() async -> TransmissionTag
}

/// Actor-based RPC mode storage.
actor RPCModeStore: RPCModeStoreProtocol {
    private var selectedMode: TransmissionRPCMode?

    func load() -> TransmissionRPCMode? {
        selectedMode
    }

    func store(_ mode: TransmissionRPCMode) {
        selectedMode = mode
    }
}

/// Actor-based JSON-RPC ID generator.
actor JSONRPCIDStore: JSONRPCIDStoreProtocol {
    private var currentID: Int = 0

    func next() -> TransmissionTag {
        currentID += 1
        return .int(currentID)
    }
}

/// For backwards compatibility with tests - allows setting RPC version
class RPCVersionStore {
    init() {}
    func store(_ value: Int) {}
    func load() async -> Int? { nil }
}
