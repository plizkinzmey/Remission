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

        let isCompatible = rpcVersion >= minimumRpcVersion

        if config.enableLogging {
            let message =
                "Server RPC version: \(rpcVersion), compatible: \(isCompatible) (minimum: \(minimumRpcVersion))"
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
            isCompatible: isCompatible
        )
    }
}
