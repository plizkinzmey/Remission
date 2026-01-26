import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Actions")
struct TorrentRepositoryActionsTests {
    @Test("makeStartClosure вызывает torrentStart с raw ID и проходит success")
    func startClosureUsesRawIdentifiers() async throws {
        // Этот тест фиксирует контракт: start-команда должна передавать
        // в RPC именно raw идентификаторы торрентов без изменений.
        let recorder = ActionRecorder()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-start.success.json"
        )

        let client = makeClient(
            start: { ids in
                await recorder.recordStart(ids)
                return response
            }
        )

        let closure = TorrentRepository.makeStartClosure(client: client)
        try await closure([.init(rawValue: 1), .init(rawValue: 2)])

        #expect(await recorder.startIds == [1, 2])
    }

    @Test("makeStopClosure вызывает torrentStop с raw ID")
    func stopClosureUsesRawIdentifiers() async throws {
        // Проверяем, что stop-команда не меняет идентификаторы и просто
        // пробрасывает их в клиент Transmission.
        let recorder = ActionRecorder()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-stop.success.json"
        )

        let client = makeClient(
            stop: { ids in
                await recorder.recordStop(ids)
                return response
            }
        )

        let closure = TorrentRepository.makeStopClosure(client: client)
        try await closure([.init(rawValue: 5), .init(rawValue: 9)])

        #expect(await recorder.stopIds == [5, 9])
    }

    @Test("makeVerifyClosure вызывает torrentVerify и передаёт идентификаторы")
    func verifyClosureUsesRawIdentifiers() async throws {
        // Важный контракт: verify работает по ID, и мы обязаны отправить
        // точный набор без потерь и сортировок.
        let recorder = ActionRecorder()
        let response = TransmissionResponse(result: "success")

        let client = makeClient(
            verify: { ids in
                await recorder.recordVerify(ids)
                return response
            }
        )

        let closure = TorrentRepository.makeVerifyClosure(client: client)
        try await closure([.init(rawValue: 42)])

        #expect(await recorder.verifyIds == [42])
    }

    @Test("makeRemoveClosure передаёт deleteData и список ID")
    func removeClosurePassesDeleteFlag() async throws {
        // Этот тест подтверждает, что флаг deleteData не теряется,
        // иначе мы можем неожиданно удалить локальные данные.
        let recorder = ActionRecorder()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-remove.success.delete-data.json"
        )

        let client = makeClient(
            remove: { ids, deleteData in
                await recorder.recordRemove(ids: ids, deleteData: deleteData)
                return response
            }
        )

        let closure = TorrentRepository.makeRemoveClosure(client: client)
        try await closure([.init(rawValue: 11)], true)

        #expect(await recorder.removeIds == [11])
        #expect(await recorder.removeDeleteData == true)
    }

    @Test("makeStartClosure пробрасывает rpcError при неуспехе")
    func startClosurePropagatesRPCError() async {
        // Мы явно фиксируем поведение: при ошибке RPC ожидаем DomainMappingError,
        // чтобы вызывающий код мог корректно показать ошибку пользователю.
        let client = makeClient(
            start: { _ in TransmissionResponse(result: "permission denied") }
        )

        let closure = TorrentRepository.makeStartClosure(client: client)

        do {
            try await closure([.init(rawValue: 1)])
            Issue.record("Ожидали DomainMappingError.rpcError, но ошибка не была брошена")
        } catch let error as DomainMappingError {
            #expect(error == .rpcError(result: "permission denied", context: "torrent-start"))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}

private actor ActionRecorder {
    private(set) var startIds: [Int]?
    private(set) var stopIds: [Int]?
    private(set) var verifyIds: [Int]?
    private(set) var removeIds: [Int]?
    private(set) var removeDeleteData: Bool?

    func recordStart(_ ids: [Int]) {
        startIds = ids
    }

    func recordStop(_ ids: [Int]) {
        stopIds = ids
    }

    func recordVerify(_ ids: [Int]) {
        verifyIds = ids
    }

    func recordRemove(ids: [Int], deleteData: Bool?) {
        removeIds = ids
        removeDeleteData = deleteData
    }
}

private func makeClient(
    start: @escaping @Sendable ([Int]) async throws -> TransmissionResponse = { _ in
        fatalError("unused in tests")
    },
    stop: @escaping @Sendable ([Int]) async throws -> TransmissionResponse = { _ in
        fatalError("unused in tests")
    },
    remove: @escaping @Sendable ([Int], Bool?) async throws -> TransmissionResponse = { _, _ in
        fatalError("unused in tests")
    },
    verify: @escaping @Sendable ([Int]) async throws -> TransmissionResponse = { _ in
        fatalError("unused in tests")
    }
) -> TransmissionClientDependency {
    TransmissionClientDependency(
        sessionGet: { fatalError("unused in tests") },
        sessionSet: { _ in fatalError("unused in tests") },
        sessionStats: { fatalError("unused in tests") },
        freeSpace: { _ in fatalError("unused in tests") },
        torrentGet: { _, _ in fatalError("unused in tests") },
        torrentAdd: { _, _, _, _, _ in fatalError("unused in tests") },
        torrentStart: start,
        torrentStop: stop,
        torrentRemove: remove,
        torrentSet: { _, _ in fatalError("unused in tests") },
        torrentVerify: verify,
        checkServerVersion: { fatalError("unused in tests") },
        performHandshake: { fatalError("unused in tests") },
        setTrustDecisionHandler: { _ in }
    )
}
