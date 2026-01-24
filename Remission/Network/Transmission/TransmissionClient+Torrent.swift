import Foundation

extension TransmissionClient {
    public func torrentGet(ids: [Int]? = nil, fields: [String]? = nil) async throws
        -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]
        if let ids {
            arguments["ids"] = .array(ids.map { .int($0) })
        }
        if let fields {
            arguments["fields"] = .array(fields.map { .string($0) })
        }

        return try await sendRequest(
            method: RPCMethod.torrentGet,
            arguments: arguments.isEmpty ? nil : .object(arguments)
        )
    }

    public func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]
        if let filename {
            arguments["filename"] = .string(filename)
        }
        if let metainfo {
            arguments["metainfo"] = .string(metainfo.base64EncodedString())
        }
        if let downloadDir {
            arguments["download-dir"] = .string(downloadDir)
        }
        if let paused {
            arguments["paused"] = .bool(paused)
        }
        if let labels {
            arguments["labels"] = .array(labels.map { .string($0) })
        }

        return try await sendRequest(
            method: RPCMethod.torrentAdd,
            arguments: .object(arguments)
        )
    }

    public func torrentRemove(ids: [Int], deleteLocalData: Bool?) async throws
        -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [
            "ids": .array(ids.map { .int($0) })
        ]
        if let deleteLocalData {
            arguments["delete-local-data"] = .bool(deleteLocalData)
        }

        return try await sendRequest(
            method: RPCMethod.torrentRemove,
            arguments: .object(arguments)
        )
    }

    public func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: RPCMethod.torrentStart,
            arguments: .object(["ids": .array(ids.map { .int($0) })])
        )
    }

    public func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: RPCMethod.torrentStop,
            arguments: .object(["ids": .array(ids.map { .int($0) })])
        )
    }

    public func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: RPCMethod.torrentVerify,
            arguments: .object(["ids": .array(ids.map { .int($0) })])
        )
    }

    public func torrentSet(ids: [Int], arguments: AnyCodable) async throws
        -> TransmissionResponse {
        var argsDict: [String: AnyCodable] = [:]
        if case .object(let dict) = arguments {
            argsDict = dict
        }
        argsDict["ids"] = .array(ids.map { .int($0) })

        return try await sendRequest(
            method: RPCMethod.torrentSet,
            arguments: .object(argsDict)
        )
    }
}
