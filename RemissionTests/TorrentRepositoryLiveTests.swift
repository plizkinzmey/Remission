import Dependencies
import Testing

@testable import Remission

@Suite("TorrentRepository liveValue")
struct TorrentRepositoryLiveTests {
    @Test("fetchList возвращает доменные модели и запрашивает минимальные поля")
    func fetchListSuccess() async throws {
        let response: TransmissionResponse =
            try TransmissionFixture.response(.torrentGetSingleActive)

        var dependency = TransmissionClientDependency.placeholder
        dependency.torrentGet = { ids, fields in
            #expect(ids == nil)
            #expect(fields == TorrentListFields.summary)
            return response
        }

        let repository = TorrentRepository.live(transmissionClient: dependency)

        let torrents = try await repository.fetchList()

        #expect(torrents.count == 1)
        #expect(torrents.first?.id.rawValue == 7)
    }

    @Test("fetchList корректно возвращает пустой массив")
    func fetchListEmpty() async throws {
        let response = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        var dependency = TransmissionClientDependency.placeholder
        dependency.torrentGet = { _, _ in response }

        let repository = TorrentRepository.live(transmissionClient: dependency)
        let torrents = try await repository.fetchList()

        #expect(torrents.isEmpty)
    }

    @Test("fetchList пробрасывает DomainMappingError.rpcError при ответе ошибки")
    func fetchListRpcError() async {
        let response = TransmissionResponse(result: "error: unauthorized")

        var dependency = TransmissionClientDependency.placeholder
        dependency.torrentGet = { _, _ in response }

        let repository = TorrentRepository.live(transmissionClient: dependency)

        await #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "torrent-get"
            ),
            performing: {
                _ = try await repository.fetchList()
            }
        )
    }
}
