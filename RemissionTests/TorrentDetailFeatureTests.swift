import ComposableArchitecture
import Foundation
import Testing
import XCTest

@testable import Remission

// swiftlint:disable explicit_type_interface function_body_length type_body_length

@MainActor
struct TorrentDetailFeatureTests {
    @Test
    func loadTorrentDetailsSuccess() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1)
        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Ubuntu"),
                        "status": .int(4),
                        "percentDone": .double(0.75),
                        "totalSize": .int(1024),
                        "downloadedEver": .int(768),
                        "uploadedEver": .int(256),
                        "eta": .int(120),
                        "rateDownload": .int(500_000),
                        "rateUpload": .int(100_000),
                        "uploadRatio": .double(1.5),
                        "downloadLimit": .int(1500),
                        "downloadLimited": .bool(true),
                        "uploadLimit": .int(750),
                        "uploadLimited": .bool(false),
                        "peersConnected": .int(5),
                        "peersFrom": .object([
                            "cache": .int(3),
                            "tracker": .int(2)
                        ]),
                        "downloadDir": .string("/downloads"),
                        "dateAdded": .int(123456),
                        "files": .array([
                            .object([
                                "name": .string("file1.iso"),
                                "length": .int(512),
                                "bytesCompleted": .int(512),
                                "priority": .int(2)
                            ]),
                            .object([
                                "name": .string("file2.iso"),
                                "length": .int(512),
                                "bytesCompleted": .int(256),
                                "priority": .int(0)
                            ])
                        ]),
                        "trackers": .array([
                            .object([
                                "announce": .string("https://tracker.example.com/announce"),
                                "tier": .int(0)
                            ])
                        ]),
                        "trackerStats": .array([
                            .object([
                                "id": .int(0),
                                "lastAnnounceResult": .string("success"),
                                "downloadCount": .int(10),
                                "leecherCount": .int(4),
                                "seederCount": .int(8)
                            ])
                        ])
                    ])
                ])
            ])
        )

        let store = TestStore(initialState: TorrentDetailState(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in response }
            $0.transmissionClient = client
            $0.date.now = fixedDate
        }

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.detailsLoaded(response, fixedDate)) {
            $0.isLoading = false
            $0.name = "Ubuntu"
            $0.status = 4
            $0.percentDone = 0.75
            $0.totalSize = 1024
            $0.downloadedEver = 768
            $0.uploadedEver = 256
            $0.eta = 120
            $0.rateDownload = 500_000
            $0.rateUpload = 100_000
            $0.uploadRatio = 1.5
            $0.downloadLimit = 1500
            $0.downloadLimited = true
            $0.uploadLimit = 750
            $0.uploadLimited = false
            $0.peersConnected = 5
            $0.peersFrom = [
                PeerSource(name: "cache", count: 3),
                PeerSource(name: "tracker", count: 2)
            ]
            $0.downloadDir = "/downloads"
            $0.dateAdded = 123456
            $0.files = [
                TorrentFile(
                    index: 0,
                    name: "file1.iso",
                    length: 512,
                    bytesCompleted: 512,
                    priority: 2
                ),
                TorrentFile(
                    index: 1,
                    name: "file2.iso",
                    length: 512,
                    bytesCompleted: 256,
                    priority: 0
                )
            ]
            $0.trackers = [
                TorrentTracker(index: 0, announce: "https://tracker.example.com/announce", tier: 0)
            ]
            $0.trackerStats = [
                TrackerStat(
                    trackerId: 0,
                    lastAnnounceResult: "success",
                    downloadCount: 10,
                    leecherCount: 4,
                    seederCount: 8
                )
            ]
            $0.speedHistory = [
                SpeedSample(timestamp: fixedDate, downloadRate: 500_000, uploadRate: 100_000)
            ]
        }
    }

    @Test
    func loadTorrentDetailsFailure() async throws {
        let store = TestStore(initialState: TorrentDetailState(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in throw APIError.networkUnavailable }
            $0.transmissionClient = client
            $0.date.now = Date(timeIntervalSince1970: 5)
        }

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.loadingFailed("Сеть недоступна")) {
            $0.isLoading = false
            $0.errorMessage = "Сеть недоступна"
        }
    }

    @Test
    func setPriorityUpdatesIndices() async throws {
        let baseResponse = makeBasicResponse()
        let responseStore = ResponseStore(responses: [baseResponse, baseResponse])
        let argumentStore = ArgumentStore()

        let store = TestStore(initialState: TorrentDetailState(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in
                guard let response = await responseStore.next() else {
                    throw APIError.unknown(details: "Missing response")
                }
                return response
            }
            client.torrentSet = { _, arguments in
                await argumentStore.store(arguments)
                return await MainActor.run {
                    TransmissionResponse(result: "success")
                }
            }
            $0.transmissionClient = client
            $0.date.now = Date(timeIntervalSince1970: 10)
        }

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.detailsLoaded(baseResponse, Date(timeIntervalSince1970: 10))) {
            $0.isLoading = false
            $0.name = "Torrent"
            $0.status = 4
            $0.percentDone = 0.5
            $0.totalSize = 300
            $0.downloadedEver = 150
            $0.uploadedEver = 75
            $0.eta = 60
            $0.rateDownload = 100_000
            $0.rateUpload = 50_000
            $0.uploadRatio = 0.5
            $0.downloadLimit = 1000
            $0.downloadLimited = true
            $0.uploadLimit = 500
            $0.uploadLimited = false
            $0.peersConnected = 3
            $0.peersFrom = [PeerSource(name: "tracker", count: 3)]
            $0.downloadDir = "/downloads"
            $0.dateAdded = 111
            $0.files = [
                TorrentFile(index: 0, name: "File A", length: 100, bytesCompleted: 50, priority: 1),
                TorrentFile(
                    index: 1, name: "File B", length: 200, bytesCompleted: 200, priority: 1)
            ]
            $0.trackers = [TorrentTracker(index: 0, announce: "https://tracker/announce", tier: 0)]
            $0.trackerStats = [
                TrackerStat(
                    trackerId: 0,
                    lastAnnounceResult: "ok",
                    downloadCount: 1,
                    leecherCount: 1,
                    seederCount: 2
                )
            ]
            $0.speedHistory = [
                SpeedSample(
                    timestamp: Date(timeIntervalSince1970: 10), downloadRate: 100_000,
                    uploadRate: 50_000)
            ]
        }

        await store.send(.setPriority(fileIndices: [1], priority: 2))

        await store.receive(.actionCompleted("Приоритет установлен"))

        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.detailsLoaded(baseResponse, Date(timeIntervalSince1970: 10))) {
            $0.isLoading = false
            $0.speedHistory.append(
                SpeedSample(
                    timestamp: Date(timeIntervalSince1970: 10), downloadRate: 100_000,
                    uploadRate: 50_000)
            )
        }

        let capturedArguments = await argumentStore.current()

        guard
            case .object(let dictionary) = capturedArguments,
            case .array(let values)? = dictionary["priority-high"]
        else {
            XCTFail("priority-high payload not captured")
            return
        }

        let indices: [Int] = values.compactMap {
            if case .int(let value) = $0 { return value }
            return nil
        }
        #expect(indices == [1])
    }

    // MARK: - Helpers

    private func makeBasicResponse() -> TransmissionResponse {
        TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
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
                        "downloadLimit": .int(1000),
                        "downloadLimited": .bool(true),
                        "uploadLimit": .int(500),
                        "uploadLimited": .bool(false),
                        "peersConnected": .int(3),
                        "peersFrom": .object(["tracker": .int(3)]),
                        "downloadDir": .string("/downloads"),
                        "dateAdded": .int(111),
                        "files": .array([
                            .object([
                                "name": .string("File A"),
                                "length": .int(100),
                                "bytesCompleted": .int(50),
                                "priority": .int(1)
                            ]),
                            .object([
                                "name": .string("File B"),
                                "length": .int(200),
                                "bytesCompleted": .int(200),
                                "priority": .int(1)
                            ])
                        ]),
                        "trackers": .array([
                            .object([
                                "announce": .string("https://tracker/announce"),
                                "tier": .int(0)
                            ])
                        ]),
                        "trackerStats": .array([
                            .object([
                                "id": .int(0),
                                "lastAnnounceResult": .string("ok"),
                                "downloadCount": .int(1),
                                "leecherCount": .int(1),
                                "seederCount": .int(2)
                            ])
                        ])
                    ])
                ])
            ])
        )
    }
}

// MARK: - Test Transmission Client

private actor ResponseStore {
    private var responses: [TransmissionResponse]

    init(responses: [TransmissionResponse]) {
        self.responses = responses
    }

    func next() -> TransmissionResponse? {
        guard responses.isEmpty == false else { return nil }
        return responses.removeFirst()
    }
}

private actor ArgumentStore {
    private var argument: AnyCodable?

    func store(_ value: AnyCodable) {
        argument = value
    }

    func current() -> AnyCodable? {
        argument
    }
}

// swiftlint:enable explicit_type_interface function_body_length type_body_length
