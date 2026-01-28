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
}
