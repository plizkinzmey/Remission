import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper Torrent")
struct TransmissionDomainMapperTorrentTests {
    @Test("mapTorrentList маппит фикстуру и сортирует peer sources по убыванию")
    func mapTorrentListFromFixture() throws {
        // Этот тест покрывает основной happy-path списка торрентов.
        let mapper = TransmissionDomainMapper()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-list-sample.json")

        let torrents = try mapper.mapTorrentList(from: response)

        #expect(torrents.count == 3)
        #expect(torrents[0].id.rawValue == 1001)
        #expect(torrents[1].status == .seeding)
        #expect(torrents[2].status == .isolated)

        // Проверяем сортировку источников peers: 25 > 9 > 8.
        #expect(torrents[0].summary.peers.sources.map(\.count) == [25, 9, 8])
    }

    @Test("mapTorrentDetails маппит детали и выставляет wanted=true при отсутствии fileStats")
    func mapTorrentDetailsFromFixture() throws {
        // Фикстура не содержит fileStats, поэтому wanted должен по умолчанию быть true.
        let mapper = TransmissionDomainMapper()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-get.success.single.json")

        let torrent = try mapper.mapTorrentDetails(from: response)

        #expect(torrent.details != nil)
        #expect(torrent.details?.files.count == 1)
        #expect(torrent.details?.files.first?.wanted == true)
        #expect(torrent.details?.files.first?.priority == 0)
    }

    @Test("mapTorrentAdd возвращает added для torrent-added")
    func mapTorrentAddFromFixture() throws {
        // Покрываем контракт torrent-add для успешного добавления.
        let mapper = TransmissionDomainMapper()
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-add.success.magnet.json")

        let result = try mapper.mapTorrentAdd(from: response)

        #expect(result.status == .added)
        #expect(result.id.rawValue == 8)
        #expect(result.name.contains("Fedora"))
    }

    @Test("percentDone и recheckProgress нормализуются из процентов в доли")
    func percentNormalizationForValuesGreaterThanOne() throws {
        // Transmission иногда возвращает проценты (например, 76) вместо долей (0.76).
        let mapper = TransmissionDomainMapper()
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Percent Torrent"),
                        "status": .int(4),
                        "percentDone": .double(76),
                        "recheckProgress": .double(50)
                    ])
                ])
            ])
        )

        let torrent = try mapper.mapTorrentDetails(from: response)

        #expect(torrent.summary.progress.percentDone == 0.76)
        #expect(torrent.summary.progress.recheckProgress == 0.5)
    }

    @Test("mapTorrentDetails бросает emptyCollection при пустом torrents")
    func mapTorrentDetailsThrowsOnEmptyCollection() {
        // Это важный error-path: UI должен получить понятную ошибку при пустом ответе.
        let mapper = TransmissionDomainMapper()
        let response = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        #expect(throws: DomainMappingError.emptyCollection(context: "torrent-get")) {
            _ = try mapper.mapTorrentDetails(from: response)
        }
    }

    @Test("mapTorrentList поддерживает snake_case ключи JSON-RPC 2.0")
    func mapTorrentListSupportsSnakeCase() throws {
        let mapper = TransmissionDomainMapper()
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(42),
                        "name": .string("Snake Torrent"),
                        "status": .int(4),
                        "error": .int(0),
                        "error_string": .string(""),
                        "percent_done": .double(0.5),
                        "recheck_progress": .double(0),
                        "total_size": .int(1000),
                        "downloaded_ever": .int(500),
                        "uploaded_ever": .int(200),
                        "upload_ratio": .double(0.4),
                        "eta": .int(120),
                        "rate_download": .int(100),
                        "rate_upload": .int(10),
                        "download_limit": .int(0),
                        "download_limited": .bool(false),
                        "upload_limit": .int(0),
                        "upload_limited": .bool(false),
                        "peers_connected": .int(3),
                        "peers_from": .object(["fromTracker": .int(3)])
                    ])
                ])
            ])
        )

        let list = try mapper.mapTorrentList(from: response)
        #expect(list.count == 1)
        #expect(list[0].id.rawValue == 42)
        #expect(list[0].summary.transfer.downloadRate == 100)
        #expect(list[0].summary.peers.connected == 3)
    }

    @Test("mapTorrentList использует percent_complete как fallback прогресса")
    func mapTorrentListSupportsPercentCompleteFallback() throws {
        let mapper = TransmissionDomainMapper()
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(77),
                        "name": .string("Percent Complete Torrent"),
                        "status": .int(4),
                        "percent_complete": .double(0.25),
                        "recheck_progress": .double(0)
                    ])
                ])
            ])
        )

        let list = try mapper.mapTorrentList(from: response)
        #expect(list.count == 1)
        #expect(list[0].summary.progress.percentDone == 0.25)
    }
}
