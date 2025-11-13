import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository liveValue")
struct TorrentRepositoryLiveTests {
    private let mapper = TransmissionDomainMapper()

    @Test("fetchList выполняет RPC и мапит результат")
    func fetchListSuccess() async throws {
        let response = try TransmissionFixture.response(.torrentGetSingleActive)
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        let capturedFields = LockedValue<[String]?>(nil)
        client.torrentGet = { ids, fields in
            capturedIds.set(ids)
            capturedFields.set(fields)
            return response
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        let torrents = try await repository.fetchList()

        #expect(torrents.count == 1)
        let torrent: Torrent = try #require(torrents.first)
        #expect(torrent.name == "Ubuntu 24.04 LTS")
        #expect(capturedIds.value == nil)
        #expect(capturedFields.value == TorrentListFields.summary)
    }

    @Test("fetchList корректно обрабатывает пустой список")
    func fetchListEmptyList() async throws {
        var client = TransmissionClientDependency.placeholder
        client.torrentGet = { _, _ in
            TransmissionResponse(
                result: "success",
                arguments: .object(["torrents": .array([])])
            )
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        let torrents = try await repository.fetchList()

        #expect(torrents.isEmpty)
    }

    @Test("fetchList пробрасывает DomainMappingError.rpcError при ошибке RPC")
    func fetchListRpcError() async {
        var client = TransmissionClientDependency.placeholder
        client.torrentGet = { _, _ in
            TransmissionResponse(result: "error: unauthorized")
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        await #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "torrent-get"
            )
        ) {
            _ = try await repository.fetchList()
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ newValue: Value) {
        lock.lock()
        storage = newValue
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
