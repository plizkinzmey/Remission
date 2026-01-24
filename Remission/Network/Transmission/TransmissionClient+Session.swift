import Foundation

extension TransmissionClient {
    public func sessionGet() async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionGet)
    }

    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionSet, arguments: arguments)
    }

    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: RPCMethod.sessionStats)
    }
}
