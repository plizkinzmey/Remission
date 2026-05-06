import Foundation

extension TransmissionClient {
    /// Получает информацию о свободном месте по указанному пути.
    public func freeSpace(path: String) async throws -> TransmissionResponse {
        try await sendRequest(
            method: RPCMethod.freeSpace,
            arguments: .object(["path": .string(path)])
        )
    }

    /// Проверяет версию сервера на совместимость.
    public func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
        // Reuse performHandshake logic which does session-get and version parsing
        let handshake = try await performHandshake()
        return (handshake.isCompatible, handshake.rpcVersion)
    }

    /// Выполняет рукопожатие с сервером, проверяя версию RPC и устанавливая Session ID.
    public func performHandshake() async throws -> TransmissionHandshakeResult {
        // Делаем session-get запрос.
        let response = try await sessionGet()

        guard let arguments = response.arguments,
            case .object(let dict) = arguments
        else {
            if let errorMessage = response.errorMessage {
                throw APIError.mapTransmissionError(errorMessage)
            }
            throw APIError.decodingFailed(
                underlyingError: "Missing arguments in session-get response"
            )
        }

        if config.enableLogging {
            let keys = dict.keys.joined(separator: ", ")
            config.logger.logResponse(
                method: "handshake-debug",
                statusCode: 200,
                responseBody: Data("Received keys: \(keys)".utf8),
                context: makeLogContext(method: "handshake-debug")
            )
        }

        guard let rpcVersionValue = dict["rpc-version"],
            let rpcVersion = rpcVersionValue.intValue
        else {
            guard
                let rpcVersionValue = dict["rpc_version"] ?? dict["rpc-version"],
                let rpcVersion = rpcVersionValue.intValue
            else {
                throw APIError.decodingFailed(
                    underlyingError: "Missing or invalid rpc-version/rpc_version in session-get response"
                )
            }
            return try await finalizeHandshake(dict: dict, rpcVersion: rpcVersion)
        }

        return try await finalizeHandshake(dict: dict, rpcVersion: rpcVersion)
    }

    private func finalizeHandshake(
        dict: [String: AnyCodable],
        rpcVersion: Int
    ) async throws -> TransmissionHandshakeResult {
        let serverVersionString = dict["version"]?.stringValue
        let rpcVersionSemver = (dict["rpc_version_semver"] ?? dict["rpc-version-semver"])?.stringValue
        let rpcMode: TransmissionRPCMode
        if config.rpcMode == .auto {
            rpcMode = await rpcModeStore.load() ?? .legacy
        } else {
            rpcMode = config.rpcMode
        }
        let isCompatible = rpcVersion >= minimumRpcVersion

        if config.enableLogging {
            let message =
                "Server RPC version: \(rpcVersion), semver: \(rpcVersionSemver ?? "n/a"), mode: \(rpcMode.rawValue), compatible: \(isCompatible) (minimum: \(minimumRpcVersion))"
            config.logger.logResponse(
                method: RPCMethod.sessionGet.rawValue,
                statusCode: 200,
                responseBody: Data(message.utf8),
                context: makeLogContext(method: RPCMethod.sessionGet.rawValue, statusCode: 200)
            )
        }

        guard isCompatible else {
            throw APIError.versionUnsupported(
                version: serverVersionString ?? "RPC v\(rpcVersion)"
            )
        }

        return TransmissionHandshakeResult(
            sessionID: await sessionStore.load(),
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumRpcVersion,
            serverVersionDescription: serverVersionString,
            rpcVersionSemver: rpcVersionSemver,
            rpcMode: rpcMode,
            isCompatible: isCompatible
        )
    }
}
