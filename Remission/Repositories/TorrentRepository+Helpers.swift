import Dependencies
import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

extension TorrentRepository {
    static func makeCommandClosure(
        context: String,
        rpc: @escaping @Sendable ([Int]) async throws -> TransmissionResponse
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        { ids in
            let response = try await rpc(ids.map(\.rawValue))
            try ensureSuccess(response, context: context)
        }
    }

    static func ensureSuccess(
        _ response: TransmissionResponse,
        context: String
    ) throws {
        guard response.isSuccess else {
            throw DomainMappingError.rpcError(result: response.result, context: context)
        }
    }

    static func makeTransferSettingsArguments(
        from settings: TransferSettings
    ) -> [String: AnyCodable] {
        var arguments: [String: AnyCodable] = [:]

        if let downloadLimit = settings.downloadLimit {
            arguments["downloadLimit"] = .int(downloadLimit.kilobytesPerSecond)
            arguments["downloadLimited"] = .bool(downloadLimit.isEnabled)
        }

        if let uploadLimit = settings.uploadLimit {
            arguments["uploadLimit"] = .int(uploadLimit.kilobytesPerSecond)
            arguments["uploadLimited"] = .bool(uploadLimit.isEnabled)
        }

        return arguments
    }

    static func makeFileSelectionArguments(
        from updates: [FileSelectionUpdate]
    ) -> [String: AnyCodable] {
        var filesWanted: Set<Int> = []
        var filesUnwanted: Set<Int> = []
        var priorityBuckets: [FilePriority: Set<Int>] = [
            .high: [],
            .normal: [],
            .low: []
        ]

        for update in updates {
            if let isWanted = update.isWanted {
                var target = isWanted ? filesWanted : filesUnwanted
                target.insert(update.fileIndex)
                if isWanted {
                    filesWanted = target
                } else {
                    filesUnwanted = target
                }
            }

            if let priority = update.priority {
                priorityBuckets[priority, default: []].insert(update.fileIndex)
            }
        }

        var arguments: [String: AnyCodable] = [:]
        appendArrayArgument(from: filesWanted, forKey: "files-wanted", into: &arguments)
        appendArrayArgument(from: filesUnwanted, forKey: "files-unwanted", into: &arguments)
        appendArrayArgument(
            from: priorityBuckets[.high] ?? [], forKey: "priority-high", into: &arguments)
        appendArrayArgument(
            from: priorityBuckets[.normal] ?? [],
            forKey: "priority-normal",
            into: &arguments
        )
        appendArrayArgument(
            from: priorityBuckets[.low] ?? [], forKey: "priority-low", into: &arguments)
        return arguments
    }

    private static func arrayArgument(from indices: Set<Int>) -> AnyCodable? {
        guard indices.isEmpty == false else {
            return nil
        }
        let values = indices.sorted().map { AnyCodable.int($0) }
        return .array(values)
    }

    private static func appendArrayArgument(
        from indices: Set<Int>,
        forKey key: String,
        into arguments: inout [String: AnyCodable]
    ) {
        guard let value = arrayArgument(from: indices) else { return }
        arguments[key] = value
    }
}

extension PendingTorrentInput {
    var filenameArgument: String? {
        switch payload {
        case .magnetLink(_, let rawValue):
            return rawValue
        case .torrentFile:
            return nil
        }
    }

    var metainfoArgument: Data? {
        switch payload {
        case .torrentFile(let data, _):
            return data
        case .magnetLink:
            return nil
        }
    }
}
