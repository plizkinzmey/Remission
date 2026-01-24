import Foundation

extension TransmissionClient {
    /// Получает текущие настройки и состояние сессии.
    public func sessionGet() async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionGet)
    }

    /// Обновляет настройки сессии.
    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionSet, arguments: arguments)
    }

    /// Получает статистику использования сессии (трафик, время работы).
    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionStats)
    }
}
