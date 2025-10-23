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
        let expected: TorrentDetailParsedSnapshot = TorrentDetailTestHelpers.makeParserSnapshot()

        let snapshot: TorrentDetailParsedSnapshot = try parser.parse(response)

        #expect(snapshot == expected)
    }
}
