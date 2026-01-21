import Foundation
import Testing

@testable import Remission

enum TorrentDetailTestHelpers {
    static func makeBasicResponse() -> TransmissionResponse {
        TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([.object(basicTorrentFields())])
            ])
        )
    }

    static func makeParserDependency() -> TorrentDetailParserDependency {
        var dependency: TorrentDetailParserDependency = .testValue
        dependency.parse = { response in try TorrentDetailParser().parse(response) }
        return dependency
    }

    static func makeParserResponse() -> TransmissionResponse {
        TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([.object(parserTorrentFields())])
            ])
        )
    }

    static func makeParsedTorrent() -> Torrent {
        Torrent(
            id: .init(rawValue: 1),
            name: "Ubuntu",
            status: .downloading,
            summary: parserSummary(),
            details: parserDetails()
        )
    }

    private static func parserSummary() -> Torrent.Summary {
        Torrent.Summary(
            progress: .init(
                percentDone: 0.75,
                recheckProgress: 0,
                totalSize: 1_024,
                downloadedEver: 768,
                uploadedEver: 256,
                uploadRatio: 1.5,
                etaSeconds: 120
            ),
            transfer: .init(
                downloadRate: 500_000,
                uploadRate: 100_000,
                downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 1_500),
                uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 750)
            ),
            peers: .init(
                connected: 5,
                sources: [
                    PeerSource(name: "cache", count: 3),
                    PeerSource(name: "tracker", count: 2)
                ]
            )
        )
    }

    private static func parserDetails() -> Torrent.Details {
        Torrent.Details(
            downloadDirectory: "/downloads",
            addedDate: Date(timeIntervalSince1970: 123_456),
            files: parserSnapshotFiles(),
            trackers: [
                TorrentTracker(
                    id: 0,
                    announce: "https://tracker.example.com/announce",
                    tier: 0
                )
            ],
            trackerStats: [
                TrackerStat(
                    trackerId: 0,
                    lastAnnounceResult: "success",
                    downloadCount: 10,
                    leecherCount: 4,
                    seederCount: 8
                )
            ],
            speedSamples: []
        )
    }

    private static func basicTorrentFields() -> [String: AnyCodable] {
        var fields: [String: AnyCodable] = [
            "id": .int(1),
            "name": .string("Torrent"),
            "status": .int(4),
            "percentDone": .double(0.5),
            "totalSize": .int(300),
            "downloadedEver": .int(150),
            "uploadedEver": .int(75),
            "eta": .int(60),
            "rateDownload": .int(100_000),
            "rateUpload": .int(50_000),
            "uploadRatio": .double(0.5),
            "downloadLimit": .int(1_000),
            "downloadLimited": .bool(true),
            "uploadLimit": .int(500),
            "uploadLimited": .bool(false),
            "peersConnected": .int(3),
            "peersFrom": .object(["tracker": .int(3)]),
            "downloadDir": .string("/downloads"),
            "dateAdded": .int(111)
        ]
        fields["files"] = .array(basicFiles())
        fields["fileStats"] = .array(basicFileStats())
        fields["trackers"] = .array(basicTrackers())
        fields["trackerStats"] = .array(basicTrackerStats())
        return fields
    }

    private static func basicFiles() -> [AnyCodable] {
        [
            .object([
                "name": .string("File A"),
                "length": .int(100),
                "bytesCompleted": .int(50)
            ]),
            .object([
                "name": .string("File B"),
                "length": .int(200),
                "bytesCompleted": .int(200)
            ])
        ]
    }

    private static func basicFileStats() -> [AnyCodable] {
        [
            .object([
                "wanted": .bool(true),
                "priority": .int(0)
            ]),
            .object([
                "wanted": .bool(true),
                "priority": .int(0)
            ])
        ]
    }

    private static func basicTrackers() -> [AnyCodable] {
        [
            .object([
                "announce": .string("https://tracker/announce"),
                "tier": .int(0)
            ])
        ]
    }

    private static func basicTrackerStats() -> [AnyCodable] {
        [
            .object([
                "id": .int(0),
                "lastAnnounceResult": .string("ok"),
                "downloadCount": .int(1),
                "leecherCount": .int(1),
                "seederCount": .int(2)
            ])
        ]
    }

    private static func parserTorrentFields() -> [String: AnyCodable] {
        var fields: [String: AnyCodable] = basicTorrentFields()
        fields["name"] = .string("Ubuntu")
        fields["percentDone"] = .double(0.75)
        fields["totalSize"] = .int(1_024)
        fields["downloadedEver"] = .int(768)
        fields["uploadedEver"] = .int(256)
        fields["eta"] = .int(120)
        fields["rateDownload"] = .int(500_000)
        fields["rateUpload"] = .int(100_000)
        fields["uploadRatio"] = .double(1.5)
        fields["downloadLimit"] = .int(1_500)
        fields["uploadLimit"] = .int(750)
        fields["peersConnected"] = .int(5)
        fields["peersFrom"] = .object([
            "cache": .int(3),
            "tracker": .int(2)
        ])
        fields["dateAdded"] = .int(123_456)
        fields["files"] = .array(parserFileCodables())
        fields["fileStats"] = .array(parserFileStatsCodables())
        fields["trackers"] = .array(parserTrackerCodables())
        fields["trackerStats"] = .array(parserTrackerStatCodables())
        return fields
    }

    private static func parserFileCodables() -> [AnyCodable] {
        [
            .object([
                "name": .string("file1.iso"),
                "length": .int(512),
                "bytesCompleted": .int(512)
            ]),
            .object([
                "name": .string("file2.iso"),
                "length": .int(512),
                "bytesCompleted": .int(256)
            ])
        ]
    }

    private static func parserFileStatsCodables() -> [AnyCodable] {
        [
            .object([
                "wanted": .bool(true),
                "priority": .int(1)
            ]),
            .object([
                "wanted": .bool(true),
                "priority": .int(-1)
            ])
        ]
    }

    private static func parserSnapshotFiles() -> [TorrentFile] {
        [
            TorrentFile(
                index: 0,
                name: "file1.iso",
                length: 512,
                bytesCompleted: 512,
                priority: 1,
                wanted: true
            ),
            TorrentFile(
                index: 1,
                name: "file2.iso",
                length: 512,
                bytesCompleted: 256,
                priority: -1,
                wanted: true
            )
        ]
    }

    private static func parserTrackerCodables() -> [AnyCodable] {
        [
            .object([
                "announce": .string("https://tracker.example.com/announce"),
                "tier": .int(0)
            ])
        ]
    }

    private static func parserTrackerStatCodables() -> [AnyCodable] {
        [
            .object([
                "id": .int(0),
                "lastAnnounceResult": .string("success"),
                "downloadCount": .int(10),
                "leecherCount": .int(4),
                "seederCount": .int(8)
            ])
        ]
    }
}

actor ResponseStore {
    private var responses: [TransmissionResponse]

    init(responses: [TransmissionResponse]) {
        self.responses = responses
    }

    func next() -> TransmissionResponse? {
        guard responses.isEmpty == false else { return nil }
        return responses.removeFirst()
    }
}

actor ArgumentStore {
    private var argument: AnyCodable?

    func store(_ value: AnyCodable) {
        argument = value
    }

    func current() -> AnyCodable? {
        argument
    }
}
