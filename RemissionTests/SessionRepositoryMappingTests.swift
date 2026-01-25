import Foundation
import Testing

@testable import Remission

@Suite("SessionRepository Mapping")
struct SessionRepositoryMappingTests {
    @Test("makeSessionSetArguments возвращает nil для пустого update")
    func makeSessionSetArgumentsReturnsNilForEmptyUpdate() {
        // Пустые обновления не должны отправлять session-set.
        let arguments = SessionRepository.makeSessionSetArguments(update: .init())
        #expect(arguments == nil)
    }

    @Test("makeSessionSetArguments формирует аргументы для лимитов, очередей и seed ratio")
    func makeSessionSetArgumentsBuildsExpectedPayload() {
        // Этот тест фиксирует ключи RPC-контракта и то, как мы маппим доменные структуры.
        let update = SessionRepository.SessionUpdate(
            speedLimits: .init(
                download: .init(isEnabled: true, kilobytesPerSecond: 512),
                upload: .init(isEnabled: false, kilobytesPerSecond: 128),
                alternative: .init(
                    isEnabled: true, downloadKilobytesPerSecond: 256, uploadKilobytesPerSecond: 64)
            ),
            queue: .init(
                downloadLimit: .init(isEnabled: true, count: 3),
                seedLimit: .init(isEnabled: false, count: 5),
                considerStalled: true,
                stalledMinutes: 30
            ),
            seedRatioLimit: .init(isEnabled: true, value: 1.5)
        )

        let payload = SessionRepository.makeSessionSetArguments(update: update)
        let dict = payload?.objectValue

        #expect(dict?["speed-limit-down-enabled"] == .bool(true))
        #expect(dict?["speed-limit-down"] == .int(512))
        #expect(dict?["seed-queue-enabled"] == .bool(false))
        #expect(dict?["queue-stalled-minutes"] == .int(30))
        #expect(dict?["seedRatioLimited"] == .bool(true))
        #expect(dict?["seedRatioLimit"] == .double(1.5))
    }

    @Test("seedRatioLimit не отправляется, когда лимит выключен")
    func disabledSeedRatioDoesNotSendLimitValue() {
        // Контракт: seedRatioLimit отправляем только при isEnabled == true.
        let update = SessionRepository.SessionUpdate(
            seedRatioLimit: .init(isEnabled: false, value: 9.9)
        )

        let payload = SessionRepository.makeSessionSetArguments(update: update)
        let dict = payload?.objectValue

        #expect(dict?["seedRatioLimited"] == .bool(false))
        #expect(dict?["seedRatioLimit"] == nil)
    }

    @Test("fetchSessionState кеширует результат и использует freeSpace при успехе")
    func fetchSessionStateCachesAndUsesFreeSpace() async throws {
        // Проверяем wiring сетевых вызовов и кеширования.
        let mapper = TransmissionDomainMapper()
        let recorder = SessionCacheRecorder()

        let client = makeTransmissionClient(
            session: makeSessionResponse(downloadDir: "/downloads"),
            stats: makeStatsResponse(),
            freeSpace: .success(makeFreeSpaceResponse(bytes: 5_000))
        )

        let state = try await SessionRepository.fetchSessionState(
            transmissionClient: client,
            mapper: mapper,
            cacheState: recorder.cache
        )

        #expect(state.storage.freeBytes == 5_000)
        #expect(await recorder.cached?.storage.freeBytes == 5_000)
        #expect(await recorder.cacheCount == 1)
    }

    @Test("fetchSessionState подставляет freeSpace=0, когда free-space падает")
    func fetchSessionStateFallsBackToZeroFreeSpace() async throws {
        // Ошибка free-space не должна ронять весь session-get.
        enum FreeSpaceError: Error { case failed }

        let mapper = TransmissionDomainMapper()
        let recorder = SessionCacheRecorder()

        let client = makeTransmissionClient(
            session: makeSessionResponse(downloadDir: "/downloads"),
            stats: makeStatsResponse(),
            freeSpace: .failure(FreeSpaceError.failed)
        )

        let state = try await SessionRepository.fetchSessionState(
            transmissionClient: client,
            mapper: mapper,
            cacheState: recorder.cache
        )

        #expect(state.storage.freeBytes == 0)
        #expect(await recorder.cached?.storage.freeBytes == 0)
    }
}

private actor SessionCacheRecorder {
    private(set) var cached: SessionState?
    private(set) var cacheCount = 0

    func cache(_ state: SessionState) async throws {
        cached = state
        cacheCount += 1
    }
}

private func makeTransmissionClient(
    session: TransmissionResponse,
    stats: TransmissionResponse,
    freeSpace: Result<TransmissionResponse, Error>
) -> TransmissionClientDependency {
    TransmissionClientDependency(
        sessionGet: { session },
        sessionSet: { _ in fatalError("unused in tests") },
        sessionStats: { stats },
        freeSpace: { _ in
            switch freeSpace {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        },
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
