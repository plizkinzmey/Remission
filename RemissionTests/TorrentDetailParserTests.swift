import Foundation
import Testing

@testable import Remission

@Suite("TorrentDetailParser")
struct TorrentDetailParserTests {
    @Test("parse успешно маппит детальный ответ torrent-get")
    func parseMapsTorrentDetailsFromFixture() throws {
        // Используем реальную фикстуру, чтобы зафиксировать контракт с Transmission RPC.
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-get.success.single.json"
        )

        let torrent = try TorrentDetailParser().parse(response)

        #expect(torrent.id.rawValue == 7)
        #expect(torrent.status == .downloading)
        #expect(torrent.details != nil)
        #expect(torrent.details?.files.count == 1)
        #expect(torrent.details?.trackers.count == 1)
    }

    @Test("parse превращает emptyCollection в missingTorrentData")
    func parseMapsEmptyCollectionToMissingTorrentData() {
        // Это явно оговорённое поведение: пустой массив torrents — это ошибка данных.
        let response = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        #expect(throws: TorrentDetailParserError.missingTorrentData) {
            _ = try TorrentDetailParser().parse(response)
        }
    }

    @Test("parse оборачивает остальные ошибки маппинга в mappingFailed")
    func parseWrapsOtherMappingErrors() {
        // Проверяем, что ошибки маппера не теряются и корректно прокидываются наверх.
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Broken torrent"),
                        "status": .int(999)
                    ])
                ])
            ])
        )

        #expect(throws: TorrentDetailParserError.mappingFailed(.unsupportedStatus(rawValue: 999))) {
            _ = try TorrentDetailParser().parse(response)
        }
    }
}
