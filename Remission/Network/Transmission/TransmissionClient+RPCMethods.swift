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
        try await sendRequest(method: "session-get")
    }

    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: "session-set", arguments: arguments)
    }

    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: "session-stats")
    }

    public func freeSpace(path: String) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["path": .string(path)]
        return try await sendRequest(method: "free-space", arguments: anyCodable(from: arguments))
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
                method: "session-get",
                statusCode: 200,
                responseBody: logMessage,
                context: makeLogContext(method: "session-get", statusCode: 200)
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

        if let ids = ids {
            arguments["ids"] = .array(ids.map { .int($0) })
        }

        if let fields = fields {
            arguments["fields"] = .array(fields.map { .string($0) })
        }

        let args: AnyCodable? = arguments.isEmpty ? nil : anyCodable(from: arguments)
        return try await sendRequest(method: "torrent-get", arguments: args)
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

        if let filename {
            arguments["filename"] = .string(filename)
        }

        guard arguments["metainfo"] != nil || arguments["filename"] != nil else {
            throw APIError.unknown(details: "torrent-add requires filename or metainfo")
        }

        if let downloadDir = downloadDir {
            arguments["download-dir"] = .string(downloadDir)
        }

        if let paused = paused {
            arguments["paused"] = .bool(paused)
        }

        if let labels = labels {
            arguments["labels"] = .array(labels.map { .string($0) })
        }

        return try await sendRequest(method: "torrent-add", arguments: anyCodable(from: arguments))
    }

    public func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: "torrent-start", arguments: anyCodable(from: arguments))
    }

    public func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(method: "torrent-stop", arguments: anyCodable(from: arguments))
    }

    public func torrentRemove(
        ids: [Int],
        deleteLocalData: Bool?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]

        if let deleteLocalData = deleteLocalData {
            arguments["delete-local-data"] = .bool(deleteLocalData)
        }

        return try await sendRequest(
            method: "torrent-remove", arguments: anyCodable(from: arguments))
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
            method: "torrent-set", arguments: anyCodable(from: allArguments))
    }

    public func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: "torrent-verify", arguments: anyCodable(from: arguments))
    }
}

// swiftlint:enable missing_docs
