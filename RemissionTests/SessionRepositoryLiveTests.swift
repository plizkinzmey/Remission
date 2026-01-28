import Foundation
import Testing

@testable import Remission

@Suite("SessionRepository Live")
struct SessionRepositoryLiveTests {
    @Test("cacheState очищает snapshot при превышении лимита")
    func cacheStateClearsSnapshotOnSizeLimit() async throws {
        // Этот тест защищает сценарий переполнения кеша: вместо падения
        // мы должны очищать кеш и продолжать работу.
        let recorder = CacheRecorder()
        let snapshot = OfflineCacheClient(
            load: { nil },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()),
                    session: nil
                )
            },
            updateSession: { _ in
                throw OfflineCacheError.exceedsSizeLimit(bytes: 10_000, limit: 1)
            },
            clear: {
                await recorder.recordClear()
            }
        )

        let repository = SessionRepository.live(
            transmissionClient: makeTransmissionClient(),
            mapper: TransmissionDomainMapper(),
            snapshot: snapshot
        )

        try await repository.cacheState(.previewActive)

        #expect(await recorder.clearCount == 1)
    }

    @Test("loadCachedState возвращает сохранённый snapshot сессии")
    func loadCachedStateReturnsSnapshot() async throws {
        // Проверяем, что live-репозиторий прокидывает кешированную сессию,
        // а не игнорирует offline-cache слой.
        let cachedState = SessionState.previewActive
        let cachedSnapshot = CachedSnapshot(
            value: cachedState,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let snapshot = OfflineCacheClient(
            load: {
                ServerSnapshot(session: cachedSnapshot)
            },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()),
                    session: nil
                )
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let repository = SessionRepository.live(
            transmissionClient: makeTransmissionClient(),
            mapper: TransmissionDomainMapper(),
            snapshot: snapshot
        )

        let result = try await repository.loadCachedState()

        #expect(result == cachedSnapshot)
    }

    @Test("updateState не вызывает sessionSet при пустом update")
    func updateStateSkipsSessionSetWhenNoArguments() async throws {
        // Пустое обновление не должно отправлять session-set, но должно
        // возвращать актуальное состояние сессии.
        let recorder = SessionSetRecorder()
        let client = makeTransmissionClient(
            sessionSet: { arguments in
                await recorder.record(arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let repository = SessionRepository.live(
            transmissionClient: client,
            mapper: TransmissionDomainMapper(),
            snapshot: nil
        )

        _ = try await repository.updateState(.init())

        #expect(await recorder.callCount == 0)
    }
}

private actor CacheRecorder {
    private(set) var clearCount: Int = 0

    func recordClear() {
        clearCount += 1
    }
}

private actor SessionSetRecorder {
    private(set) var callCount: Int = 0

    func record(_ _: AnyCodable) {
        callCount += 1
    }
}

private func makeTransmissionClient(
    sessionSet: @escaping @Sendable (AnyCodable) async throws -> TransmissionResponse = { _ in
        fatalError("unused in tests")
    }
) -> TransmissionClientDependency {
    TransmissionClientDependency(
        sessionGet: { makeSessionResponse(downloadDir: "/downloads") },
        sessionSet: sessionSet,
        sessionStats: { makeStatsResponse() },
        freeSpace: { _ in makeFreeSpaceResponse(bytes: 0) },
        torrentGet: { _, _ in fatalError("unused in tests") },
        torrentAdd: { _, _, _, _, _ in fatalError("unused in tests") },
        torrentStart: { _ in fatalError("unused in tests") },
        torrentStop: { _ in fatalError("unused in tests") },
        torrentRemove: { _, _ in fatalError("unused in tests") },
        torrentSet: { _, _ in fatalError("unused in tests") },
        torrentVerify: { _ in fatalError("unused in tests") },
        checkServerVersion: { fatalError("unused in tests") },
        performHandshake: { fatalError("unused in tests") },
        setTrustDecisionHandler: { _ in }
    )
}

private func makeSessionResponse(downloadDir: String) -> TransmissionResponse {
    TransmissionResponse(
        result: "success",
        arguments: .object([
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.3"),
            "download-dir": .string(downloadDir)
        ])
    )
}

private func makeStatsResponse() -> TransmissionResponse {
    TransmissionResponse(
        result: "success",
        arguments: .object([
            "activeTorrentCount": .int(1),
            "pausedTorrentCount": .int(0),
            "torrentCount": .int(1),
            "downloadSpeed": .int(1000),
            "uploadSpeed": .int(2000),
            "cumulative-stats": .object([
                "filesAdded": .int(1),
                "downloadedBytes": .int(10),
                "uploadedBytes": .int(20),
                "sessionCount": .int(1),
                "secondsActive": .int(60)
            ]),
            "current-stats": .object([
                "filesAdded": .int(1),
                "downloadedBytes": .int(10),
                "uploadedBytes": .int(20),
                "sessionCount": .int(1),
                "secondsActive": .int(60)
            ])
        ])
    )
}

private func makeFreeSpaceResponse(bytes: Int) -> TransmissionResponse {
    TransmissionResponse(
        result: "success",
        arguments: .object([
            "size-bytes": .int(bytes)
        ])
    )
}
