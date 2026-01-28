import Foundation
import Testing

@testable import Remission

@Suite("Offline Cache Repository Tests")
struct OfflineCacheRepositoryTests {
    private final class TimeBox: @unchecked Sendable {
        var now: Date
        init(now: Date) { self.now = now }
    }

    private func makeKey(id: UUID) -> OfflineCacheKey {
        OfflineCacheKey(serverID: id, cacheFingerprint: "fp", rpcVersion: 17)
    }

    // Проверяет сценарий update/load/clear для inMemory репозитория.
    @Test
    func inMemoryRepositoryUpdateLoadAndClear() async throws {
        let time = TimeBox(now: Date(timeIntervalSince1970: 100))
        let repository = OfflineCacheRepository.inMemory(
            policy: OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1_000_000),
            now: { time.now },
            logger: .noop
        )

        let serverID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let key = makeKey(id: serverID)
        let client = repository.client(key)

        _ = try await client.updateTorrents([Torrent.previewDownloading])
        let loaded = try await client.load()
        #expect(loaded?.torrents?.value.count == 1)

        try await client.clear()
        let cleared = try await client.load()
        #expect(cleared == nil)
    }

    // Проверяет clearMultiple для нескольких серверов.
    @Test
    func clearMultipleRemovesSnapshotsForAllServers() async throws {
        let repository = OfflineCacheRepository.inMemory()
        let id1 = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let id2 = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!

        let client1 = repository.client(makeKey(id: id1))
        let client2 = repository.client(makeKey(id: id2))

        _ = try await client1.updateTorrents([Torrent.previewDownloading])
        _ = try await client2.updateTorrents([Torrent.previewCompleted])

        try await repository.clearMultiple([id1, id2])

        #expect(try await client1.load() == nil)
        #expect(try await client2.load() == nil)
    }
}
