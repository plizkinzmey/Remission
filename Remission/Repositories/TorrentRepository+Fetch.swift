import Dependencies
import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

extension TorrentRepository {
    static func makeFetchListClosure(
        client: TransmissionClientDependency,
        mapper: TransmissionDomainMapper,
        fields: [String],
        cache: @escaping @Sendable ([Torrent]) async throws -> Void
    ) -> @Sendable () async throws -> [Torrent] {
        {
            let response = try await client.torrentGet(nil, fields)
            let torrents = try mapper.mapTorrentList(from: response)
            try await cache(torrents)
            return torrents
        }
    }

    static func makeFetchDetailsClosure(
        client: TransmissionClientDependency,
        mapper: TransmissionDomainMapper,
        fields: [String]
    ) -> @Sendable (Torrent.Identifier) async throws -> Torrent {
        { identifier in
            let response = try await client.torrentGet(
                [identifier.rawValue],
                fields
            )
            return try mapper.mapTorrentDetails(from: response)
        }
    }
}
