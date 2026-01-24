import Dependencies
import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

extension TorrentRepository {
    static func makeCacheListClosure(
        snapshot: OfflineCacheClient?
    ) -> @Sendable ([Torrent]) async throws -> Void {
        { torrents in
            guard let snapshot else { return }
            do {
                _ = try await snapshot.updateTorrents(torrents)
            } catch OfflineCacheError.exceedsSizeLimit {
                try await snapshot.clear()
            }
        }
    }

    static func makeLoadCachedListClosure(
        snapshot: OfflineCacheClient?
    ) -> @Sendable () async throws -> CachedSnapshot<[Torrent]>? {
        {
            guard let snapshot else { return nil }
            return try await snapshot.load()?.torrents
        }
    }
}
