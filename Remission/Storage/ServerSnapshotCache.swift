import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

struct OfflineCacheClient: Sendable {
    var load: @Sendable () async throws -> ServerSnapshot?
    var updateTorrents: @Sendable ([Torrent]) async throws -> ServerSnapshot
    var updateSession: @Sendable (SessionState) async throws -> ServerSnapshot
    var clear: @Sendable () async throws -> Void
}

struct OfflineCacheRepository: Sendable {
    var policy: OfflineCachePolicy
    var client: @Sendable (_ key: OfflineCacheKey) -> OfflineCacheClient
    var clear: @Sendable (_ serverID: UUID) async throws -> Void
    var clearMultiple: @Sendable (_ serverIDs: [UUID]) async throws -> Void
}

#if canImport(ComposableArchitecture)
    extension OfflineCacheRepository: DependencyKey {
        static var liveValue: OfflineCacheRepository {
            @Dependency(\.dateProvider) var dateProvider
            @Dependency(\.appLogger) var appLogger
            let policy = OfflineCachePolicy.default
            let logger = appLogger.withCategory("offline-cache")
            let store = OfflineCacheFileStore(policy: policy, now: dateProvider.now, log: logger)

            return OfflineCacheRepository(
                policy: policy,
                client: { key in
                    OfflineCacheClient(
                        load: {
                            try await store.load(key: key)
                        },
                        updateTorrents: { torrents in
                            try await store.update(key: key, torrents: torrents)
                        },
                        updateSession: { session in
                            try await store.update(key: key, session: session)
                        },
                        clear: {
                            try await store.clear(serverID: key.serverID)
                        }
                    )
                },
                clear: { serverID in
                    try await store.clear(serverID: serverID)
                },
                clearMultiple: { serverIDs in
                    try await store.clearMultiple(serverIDs: serverIDs)
                }
            )
        }

        static var previewValue: OfflineCacheRepository {
            .inMemory()
        }

        static var testValue: OfflineCacheRepository {
            .inMemory()
        }
    }

    extension OfflineCacheRepository {
        static func inMemory(
            policy: OfflineCachePolicy = .default,
            now: @escaping @Sendable () -> Date = { Date() },
            logger: AppLogger = .noop
        ) -> OfflineCacheRepository {
            let store = InMemoryOfflineCacheStore(policy: policy, now: now, log: logger)
            return OfflineCacheRepository(
                policy: policy,
                client: { key in
                    OfflineCacheClient(
                        load: {
                            await store.load(key: key)
                        },
                        updateTorrents: { torrents in
                            try await store.update(key: key, torrents: torrents)
                        },
                        updateSession: { session in
                            try await store.update(key: key, session: session)
                        },
                        clear: {
                            await store.clear(serverID: key.serverID)
                        }
                    )
                },
                clear: { serverID in
                    await store.clear(serverID: serverID)
                },
                clearMultiple: { serverIDs in
                    await store.clearMultiple(serverIDs: serverIDs)
                }
            )
        }
    }

    extension DependencyValues {
        var offlineCacheRepository: OfflineCacheRepository {
            get { self[OfflineCacheRepository.self] }
            set { self[OfflineCacheRepository.self] = newValue }
        }
    }
#endif
