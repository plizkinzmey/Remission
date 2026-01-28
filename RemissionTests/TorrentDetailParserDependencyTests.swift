import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("TorrentDetailParserDependency Tests")
struct TorrentDetailParserDependencyTests {

    @Test
    func liveValueUsesParser() throws {
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-get.success.single.json"
        )

        let parser = TorrentDetailParserDependency.liveValue
        let torrent = try parser.parse(response)

        #expect(torrent.id.rawValue == 7)
    }

    @Test
    func placeholderThrowsNotConfigured() {
        // testValue defaults to placeholder in this implementation
        let parser = TorrentDetailParserDependency.testValue
        let response = TransmissionResponse(result: "success", arguments: .object([:]))

        #expect(throws: TorrentDetailParserDependencyError.notConfigured("parse")) {
            try parser.parse(response)
        }
    }
}
