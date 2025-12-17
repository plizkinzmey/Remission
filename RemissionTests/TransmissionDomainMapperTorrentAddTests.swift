import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper torrent-add")
struct TransmissionDomainMapperTorrentAddTests {
    private let mapper = TransmissionDomainMapper()

    @Test
    func parsesAddedPayload() throws {
        let response = try TransmissionFixture.response(.torrentAddSuccessMagnet)
        let result = try mapper.mapTorrentAdd(from: response)

        #expect(result.status == .added)
        #expect(result.id == .init(rawValue: 8))
        #expect(result.name == "Fedora-Workstation-Live-x86_64-40")
        #expect(result.hashString == "b73fc0c25fbf79bd5f9f0b61b7a44d64d3fabcde")
    }

    @Test
    func parsesDuplicatePayload() throws {
        let response = try TransmissionFixture.response(.torrentAddDuplicateMagnet)
        let result = try mapper.mapTorrentAdd(from: response)

        #expect(result.status == .duplicate)
        #expect(result.id == .init(rawValue: 9))
        #expect(result.name.contains("Fedora-Workstation"))
    }

    @Test
    func missingAddPayloadThrows() {
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([:]),
            tag: nil
        )

        #expect(
            throws: DomainMappingError.missingField(
                field: "torrent-added|torrent-duplicate",
                context: "torrent-add"
            )
        ) {
            _ = try mapper.mapTorrentAdd(from: response)
        }
    }
}
