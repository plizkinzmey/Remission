import Foundation

public enum TransmissionRPCMode: String, Sendable, Codable {
    case auto
    case legacy
    case jsonRpc2
}

struct JSONRPCRequest: Codable, Sendable, Equatable {
    let jsonrpc: String
    let method: String
    let params: AnyCodable?
    let id: TransmissionTag?

    init(method: String, params: AnyCodable?, id: TransmissionTag?) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
        self.id = id
    }
}

struct JSONRPCResponse: Codable, Sendable, Equatable {
    let jsonrpc: String?
    let result: AnyCodable?
    let error: JSONRPCError?
    let id: TransmissionTag?
}

struct JSONRPCError: Codable, Sendable, Equatable {
    let code: Int
    let message: String
    let data: AnyCodable?
}
