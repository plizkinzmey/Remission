// TransmissionRPCProtocol.swift
// Remission
//
// Shared types and enums for Transmission RPC protocol.

import Foundation

/// RPC protocol mode.
public enum TransmissionRPCMode: String, Sendable, Codable {
    case auto
    case legacy
    case jsonRpc2
}

/// RPC method names for Transmission API.
public enum TransmissionRPCMethod: String, Sendable {
    case sessionGet = "session-get"
    case sessionSet = "session-set"
    case sessionStats = "session-stats"
    case freeSpace = "free-space"
    case torrentGet = "torrent-get"
    case torrentSet = "torrent-set"
    case torrentAdd = "torrent-add"
    case torrentRemove = "torrent-remove"
    case torrentStart = "torrent-start"
    case torrentStop = "torrent-stop"
    case torrentVerify = "torrent-verify"
}

/// JSON-RPC 2.0 request structure.
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

/// JSON-RPC 2.0 response structure.
struct JSONRPCResponse: Codable, Sendable, Equatable {
    let jsonrpc: String?
    let result: AnyCodable?
    let error: JSONRPCError?
    let id: TransmissionTag?
}

/// JSON-RPC 2.0 error structure.
struct JSONRPCError: Codable, Sendable, Equatable {
    let code: Int
    let message: String
    let data: AnyCodable?
}
