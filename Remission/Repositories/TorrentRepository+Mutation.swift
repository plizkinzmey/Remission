import Dependencies
import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

extension TorrentRepository {
    static func makeAddClosure(
        client: TransmissionClientDependency,
        mapper: TransmissionDomainMapper
    ) -> @Sendable (PendingTorrentInput, String, Bool, [String]?) async throws -> AddResult {
        { input, destination, startPaused, labels in
            let response = try await client.torrentAdd(
                filename: input.filenameArgument,
                metainfo: input.metainfoArgument,
                downloadDir: destination,
                paused: startPaused,
                labels: labels
            )
            let addResult = try mapper.mapTorrentAdd(from: response)

            // If the server is older (RPC < 17) and we have labels, set them via torrent-set
            if let labels, labels.isEmpty == false {
                let checkVersion = try await client.checkServerVersion()
                if checkVersion.rpcVersion < 17 {
                    let arguments: [String: AnyCodable] = [
                        "labels": .array(labels.map { .string($0) })
                    ]
                    _ = try await client.torrentSet(
                        [addResult.id.rawValue],
                        .object(arguments)
                    )
                }
            }

            return addResult
        }
    }

    static func makeUpdateTransferSettingsClosure(
        client: TransmissionClientDependency
    ) -> @Sendable (TransferSettings, [Torrent.Identifier]) async throws -> Void {
        { settings, ids in
            let arguments = makeTransferSettingsArguments(from: settings)
            guard arguments.isEmpty == false else {
                return
            }
            let response = try await client.torrentSet(
                ids.map(\.rawValue),
                .object(arguments)
            )
            try ensureSuccess(response, context: "torrent-set")
        }
    }

    static func makeUpdateLabelsClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([String], [Torrent.Identifier]) async throws -> Void {
        { labels, ids in
            guard labels.isEmpty == false else { return }
            let arguments: [String: AnyCodable] = [
                "labels": .array(labels.map { .string($0) })
            ]
            let response = try await client.torrentSet(
                ids.map(\.rawValue),
                .object(arguments)
            )
            try ensureSuccess(response, context: "torrent-set")
        }
    }

    static func makeUpdateFileSelectionClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([FileSelectionUpdate], Torrent.Identifier) async throws -> Void {
        { updates, torrentID in
            let arguments = makeFileSelectionArguments(from: updates)
            guard arguments.isEmpty == false else {
                return
            }
            let response = try await client.torrentSet(
                [torrentID.rawValue],
                .object(arguments)
            )
            try ensureSuccess(response, context: "torrent-set")
        }
    }
}
