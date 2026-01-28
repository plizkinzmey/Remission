import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Fetch")
struct TorrentRepositoryFetchTests {
    @Test("makeFetchListClosure вызывает torrentGet, кеширует и возвращает список")
    func fetchListCallsTorrentGetAndCaches() async throws {
        // Этот тест проверяет полный happy-path: запрос → маппинг → кеш → результат.
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-list-sample.json"
        )
        let mapper = TransmissionDomainMapper()
        let recorder = FetchRecorder()
        let cacheRecorder = CacheRecorder()
        let fields = ["id", "name", "status"]

        let client = makeClient(
            torrentGet: { ids, requestFields in
                await recorder.record(ids: ids, fields: requestFields)
                return response
            }
        )

        let closure = TorrentRepository.makeFetchListClosure(
            client: client,
            mapper: mapper,
            fields: fields,
            cache: { torrents in
                await cacheRecorder.record(torrents)
            }
        )

        let result = try await closure()

        #expect(await recorder.ids == nil)
        #expect(await recorder.fields == fields)
        #expect(result.map(\.id.rawValue) == [1001, 1002, 1003])
        #expect(await cacheRecorder.torrents?.map(\.id.rawValue) == [1001, 1002, 1003])
    }

    @Test("makeFetchDetailsClosure передаёт ID и возвращает детали торрента")
    func fetchDetailsPassesIdentifierAndMapsDetails() async throws {
        // Фиксируем контракт: details-запрос должен передавать конкретный ID,
        // а результат обязан содержать заполненные детали.
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-get.success.single.json"
        )
        let mapper = TransmissionDomainMapper()
        let recorder = FetchRecorder()
        let fields = ["id", "name", "status", "downloadDir"]

        let client = makeClient(
            torrentGet: { ids, requestFields in
                await recorder.record(ids: ids, fields: requestFields)
                return response
            }
        )

        let closure = TorrentRepository.makeFetchDetailsClosure(
            client: client,
            mapper: mapper,
            fields: fields
        )

        let result = try await closure(.init(rawValue: 7))

        #expect(await recorder.ids == [7])
        #expect(await recorder.fields == fields)
        #expect(result.id.rawValue == 7)
        #expect(result.details?.downloadDirectory == "/volume1/Downloads")
    }

    @Test("makeFetchListClosure пробрасывает ошибку маппинга при отсутствии arguments")
    func fetchListPropagatesMappingError() async {
        // Сценарий защиты: если сервер прислал некорректный ответ,
        // ошибка должна доходить до вызывающего кода без подмены.
        let response = TransmissionResponse(result: "success", arguments: nil)
        let mapper = TransmissionDomainMapper()

        let client = makeClient(
            torrentGet: { _, _ in response }
        )

        let closure = TorrentRepository.makeFetchListClosure(
            client: client,
            mapper: mapper,
            fields: ["id"],
            cache: { _ in }
        )

        do {
            _ = try await closure()
            Issue.record("Ожидали DomainMappingError.missingArguments, но ошибка не была брошена")
        } catch let error as DomainMappingError {
            #expect(error == .missingArguments(context: "TorrentGetArguments"))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }

    @Test("makeFetchDetailsClosure бросает emptyCollection при пустом torrents")
    func fetchDetailsFailsOnEmptyCollection() async {
        // Этот тест фиксирует корректную диагностику, когда torrent-get
        // вернул пустой список вместо ожидаемого элемента.
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([])
            ])
        )
        let mapper = TransmissionDomainMapper()

        let client = makeClient(
            torrentGet: { _, _ in response }
        )

        let closure = TorrentRepository.makeFetchDetailsClosure(
            client: client,
            mapper: mapper,
            fields: ["id"]
        )

        do {
            _ = try await closure(.init(rawValue: 1))
            Issue.record("Ожидали DomainMappingError.emptyCollection, но ошибка не была брошена")
        } catch let error as DomainMappingError {
            #expect(error == .emptyCollection(context: "torrent-get"))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}

private actor FetchRecorder {
    private(set) var ids: [Int]?
    private(set) var fields: [String]?

    func record(ids: [Int]?, fields: [String]?) {
        self.ids = ids
        self.fields = fields
    }
}

private actor CacheRecorder {
    private(set) var torrents: [Torrent]?

    func record(_ torrents: [Torrent]) {
        self.torrents = torrents
    }
}

private func makeClient(
    torrentGet: @escaping @Sendable ([Int]?, [String]?) async throws -> TransmissionResponse
) -> TransmissionClientDependency {
    TransmissionClientDependency(
        sessionGet: { fatalError("unused in tests") },
        sessionSet: { _ in fatalError("unused in tests") },
        sessionStats: { fatalError("unused in tests") },
        freeSpace: { _ in fatalError("unused in tests") },
        torrentGet: torrentGet,
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
