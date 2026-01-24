import Dependencies
import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

extension TorrentRepository {
    static func makeStartClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        makeCommandClosure(
            context: "torrent-start",
            rpc: client.torrentStart
        )
    }

    static func makeStopClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        makeCommandClosure(
            context: "torrent-stop",
            rpc: client.torrentStop
        )
    }

    static func makeRemoveClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([Torrent.Identifier], Bool?) async throws -> Void {
        { ids, deleteData in
            let response = try await client.torrentRemove(
                ids.map(\.rawValue),
                deleteData
            )
            try ensureSuccess(response, context: "torrent-remove")
        }
    }

    static func makeVerifyClosure(
        client: TransmissionClientDependency
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        makeCommandClosure(
            context: "torrent-verify",
            rpc: client.torrentVerify
        )
    }
}
