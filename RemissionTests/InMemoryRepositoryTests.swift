import Foundation
import Testing

@testable import Remission

@MainActor
@Suite("InMemory repositories")
struct InMemoryRepositoryTests {
    // MARK: - Torrent

    @Test
    func torrentRepositoryFetchListSuccess() async throws {
        let store = DomainFixtures.makeTorrentStore()
        let repository = TorrentRepository.inMemory(store: store)

        let torrents = try await repository.fetchList()

        #expect(torrents.count == 2)
        #expect(torrents.first?.id == DomainFixtures.torrentDownloading.id)
    }

    @Test
    func torrentRepositoryFetchDetailsFailure() async {
        let store = DomainFixtures.makeTorrentStore()
        await store.markFailure(.fetchDetails)
        let repository = TorrentRepository.inMemory(store: store)

        await #expect(throws: InMemoryTorrentRepositoryError.self) {
            _ = try await repository.fetchDetails(.init(rawValue: 999))
        }
    }

    // MARK: - Session

    @Test
    func sessionRepositoryUpdateStateHappyPath() async throws {
        let store = DomainFixtures.makeSessionStore()
        let repository = SessionRepository.inMemory(store: store)

        let updated = try await repository.updateState(
            .init(
                speedLimits: .init(
                    download: .init(isEnabled: true, kilobytesPerSecond: 1024),
                    upload: nil,
                    alternative: nil
                ),
                queue: nil
            ))

        #expect(updated.speedLimits.download.kilobytesPerSecond == 1_024)
    }

    @Test
    func sessionRepositoryUpdateStateFailure() async {
        let store = DomainFixtures.makeSessionStore()
        await store.markFailure(.updateState)
        let repository = SessionRepository.inMemory(store: store)

        await #expect(throws: InMemorySessionRepositoryError.self) {
            _ = try await repository.updateState(.init())
        }
    }

    // MARK: - User Preferences

    @Test
    func userPreferencesRepositoryUpdatePollingInterval() async throws {
        let store = DomainFixtures.makeUserPreferencesStore()
        let repository = UserPreferencesRepository.inMemory(store: store)

        let preferences = try await repository.updatePollingInterval(10)

        #expect(preferences.pollingInterval == 10)
    }

    @Test
    func userPreferencesRepositoryMigratesLegacyVersion() async throws {
        let legacy = UserPreferences(
            pollingInterval: 7,
            isAutoRefreshEnabled: false,
            isTelemetryEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: 512,
                uploadKilobytesPerSecond: 256
            ),
            version: 1
        )
        let store = DomainFixtures.makeUserPreferencesStore(preferences: legacy)
        let repository = UserPreferencesRepository.inMemory(store: store)

        let migrated = try await repository.load()

        #expect(migrated.version == UserPreferences.currentVersion)
        #expect(migrated.isTelemetryEnabled == false)
        #expect(migrated.pollingInterval == 7)
    }

    @Test
    func userPreferencesRepositoryFailure() async {
        let store = DomainFixtures.makeUserPreferencesStore()
        await store.markFailure(.load)
        let repository = UserPreferencesRepository.inMemory(store: store)

        await #expect(throws: InMemoryUserPreferencesRepositoryError.self) {
            _ = try await repository.load()
        }
    }

    // MARK: - Offline Cache

    @Test
    func offlineCachePersistsAndClears() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let cache = OfflineCacheRepository.inMemory(now: { now })
        let key = OfflineCacheKey(
            serverID: UUID(),
            cacheFingerprint: "fixture",
            rpcVersion: 20
        )
        let client = cache.client(key)

        _ = try await client.updateTorrents([Torrent.previewDownloading])
        _ = try await client.updateSession(SessionState.previewActive)

        let loaded = try await client.load()
        #expect(loaded?.torrents?.value.first?.id == .init(rawValue: 1))
        #expect(loaded?.session?.value.rpc.rpcVersion == SessionState.previewActive.rpc.rpcVersion)
        #expect(loaded?.torrents?.updatedAt == now)

        try await client.clear()
        let cleared = try await client.load()
        #expect(cleared == nil)
    }
}
