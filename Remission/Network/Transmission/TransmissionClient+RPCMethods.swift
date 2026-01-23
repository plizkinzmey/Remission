import Foundation

// swiftlint:disable missing_docs

extension TransmissionClient {
    private func parseHandshake(
        from response: TransmissionResponse
    ) async throws -> TransmissionHandshakeResult {
        guard let arguments = response.arguments,
            case .object(let dict) = arguments
        else {
            throw APIError.decodingFailed(
                underlyingError: "Missing arguments in session-get response"
            )
        }

        guard let rpcVersionValue = dict["rpc-version"],
            case .int(let rpcVersion) = rpcVersionValue
        else {
            throw APIError.decodingFailed(
                underlyingError: "Missing or invalid rpc-version in session-get response"
            )
        }

        let serverVersionString: String?
        if case .string(let value)? = dict["version"] {
            serverVersionString = value
        } else {
            serverVersionString = nil
        }

        return TransmissionHandshakeResult(
            sessionID: await sessionStore.load(),
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumRpcVersion,
            serverVersionDescription: serverVersionString,
            isCompatible: rpcVersion >= minimumRpcVersion
        )
    }

    // MARK: - Session Methods

    public func sessionGet() async throws -> TransmissionResponse {
        try await sendRequest(method: .sessionGet)
    }

    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: .sessionSet, arguments: arguments)
    }

    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: .sessionStats)
    }

    public func freeSpace(path: String) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["path": .string(path)]
        return try await sendRequest(method: .freeSpace, arguments: anyCodable(from: arguments))
    }

    public func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
        let handshake: TransmissionHandshakeResult = try await performHandshake()
        return (handshake.isCompatible, handshake.rpcVersion)
    }

    public func performHandshake() async throws -> TransmissionHandshakeResult {
        let response: TransmissionResponse = try await sessionGet()
        let handshake: TransmissionHandshakeResult = try await parseHandshake(from: response)

        if config.enableLogging {
            let message: String =
                "Server RPC version: \(handshake.rpcVersion), compatible: \(handshake.isCompatible) (minimum: \(handshake.minimumSupportedRpcVersion))"
            let logMessage: Data = Data(message.utf8)
            config.logger.logResponse(
                method: RPCMethod.sessionGet.rawValue,
                statusCode: 200,
                responseBody: logMessage,
                context: makeLogContext(method: RPCMethod.sessionGet.rawValue, statusCode: 200)
            )
        }

        guard handshake.isCompatible else {
            throw APIError.versionUnsupported(
                version: handshake.serverVersionDescription ?? "RPC v\(handshake.rpcVersion)")
        }

        return TransmissionHandshakeResult(
            sessionID: await sessionStore.load(),
            rpcVersion: handshake.rpcVersion,
            minimumSupportedRpcVersion: handshake.minimumSupportedRpcVersion,
            serverVersionDescription: handshake.serverVersionDescription,
            isCompatible: handshake.isCompatible
        )
    }

    // MARK: - Torrent Methods

    public func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]
        arguments.set("ids", ids)
        arguments.set("fields", fields)

        let args: AnyCodable? = arguments.isEmpty ? nil : anyCodable(from: arguments)
        return try await sendRequest(method: .torrentGet, arguments: args)
    }

    public func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]

        if let metainfo {
            let base64Payload: String = metainfo.base64EncodedString()
            arguments["metainfo"] = .string(base64Payload)
        }

        arguments.set("filename", filename)
        arguments.set("download-dir", downloadDir)
        arguments.set("paused", paused)
        arguments.set("labels", labels)

        guard arguments["metainfo"] != nil || arguments["filename"] != nil else {
            throw APIError.unknown(details: "torrent-add requires filename or metainfo")
        }

        return try await sendRequest(method: .torrentAdd, arguments: anyCodable(from: arguments))
    }

    public func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: .torrentStart, arguments: anyCodable(from: arguments))
    }

    public func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(method: .torrentStop, arguments: anyCodable(from: arguments))
    }

    public func torrentRemove(
        ids: [Int],
        deleteLocalData: Bool?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        arguments.set("delete-local-data", deleteLocalData)

        return try await sendRequest(
            method: .torrentRemove, arguments: anyCodable(from: arguments))
    }

    public func torrentSet(ids: [Int], arguments: AnyCodable) async throws -> TransmissionResponse {
        var allArguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]

        // Объединяем переданные аргументы с ids
        if case .object(let dict) = arguments {
            for (key, value) in dict {
                allArguments[key] = value
            }
        }

        return try await sendRequest(
            method: .torrentSet, arguments: anyCodable(from: allArguments))
    }

    public func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: .torrentVerify, arguments: anyCodable(from: arguments))
    }
}

extension Dictionary where Key == String, Value == AnyCodable {
    fileprivate mutating func set(_ key: String, _ value: String?) {
        if let value { self[key] = .string(value) }
    }

    fileprivate mutating func set(_ key: String, _ value: Int?) {
        if let value { self[key] = .int(value) }
    }

    fileprivate mutating func set(_ key: String, _ value: Bool?) {
        if let value { self[key] = .bool(value) }
    }

    fileprivate mutating func set(_ key: String, _ value: [String]?) {
        if let value { self[key] = .array(value.map { .string($0) }) }
    }

    fileprivate mutating func set(_ key: String, _ value: [Int]?) {
        if let value { self[key] = .array(value.map { .int($0) }) }
    }
}

// swiftlint:enable missing_docs
