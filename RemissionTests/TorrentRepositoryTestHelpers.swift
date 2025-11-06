import Foundation

@testable import Remission

enum TorrentRepositoryTestError: Error, Sendable {
    case unimplemented
}

extension TorrentRepository {
    static func test(
        fetchList: @escaping @Sendable () async throws -> [Torrent] = {
            throw TorrentRepositoryTestError.unimplemented
        },
        fetchDetails: @escaping @Sendable (Torrent.Identifier) async throws -> Torrent = { _ in
            throw TorrentRepositoryTestError.unimplemented
        },
        start: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void = { _ in
            throw TorrentRepositoryTestError.unimplemented
        },
        stop: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void = { _ in
            throw TorrentRepositoryTestError.unimplemented
        },
        remove: @escaping @Sendable ([Torrent.Identifier], Bool?) async throws -> Void = { _, _ in
            throw TorrentRepositoryTestError.unimplemented
        },
        verify: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void = { _ in
            throw TorrentRepositoryTestError.unimplemented
        },
        updateTransferSettings:
            @escaping @Sendable (
                TorrentRepository.TransferSettings,
                [Torrent.Identifier]
            ) async throws -> Void = { _, _ in
                throw TorrentRepositoryTestError.unimplemented
            },
        updateFileSelection:
            @escaping @Sendable (
                [TorrentRepository.FileSelectionUpdate],
                Torrent.Identifier
            ) async throws -> Void = { _, _ in
                throw TorrentRepositoryTestError.unimplemented
            }
    ) -> TorrentRepository {
        TorrentRepository(
            fetchList: fetchList,
            fetchDetails: fetchDetails,
            start: start,
            stop: stop,
            remove: remove,
            verify: verify,
            updateTransferSettings: updateTransferSettings,
            updateFileSelection: updateFileSelection
        )
    }
}
