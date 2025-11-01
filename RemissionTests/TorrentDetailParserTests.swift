import Foundation
import Testing

@testable import Remission

struct TorrentDetailParserTests {
    private let parser: TorrentDetailParser = .init()

    @Test
    func parseMissingTorrentThrows() {
        let response: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        #expect(
            throws: TorrentDetailParserError.missingTorrentData,
            performing: { try parser.parse(response) }
        )
    }

    @Test
    func parseValidResponseMatchesSnapshot() throws {
        let response: TransmissionResponse = TorrentDetailTestHelpers.makeParserResponse()
        let expected: Torrent = TorrentDetailTestHelpers.makeParsedTorrent()

        let parsed: Torrent = try parser.parse(response)

        #expect(parsed == expected)
    }

    @Test
    func parseUnsupportedStatusProducesMappingError() {
        let response: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Broken"),
                        "status": .int(99)
                    ])
                ])
            ])
        )

        #expect(
            throws: TorrentDetailParserError.mappingFailed(
                .unsupportedStatus(rawValue: 99)
            ),
            performing: { try parser.parse(response) }
        )
    }
}
