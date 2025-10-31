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

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in response }
            $0.transmissionClient = client
            $0.date.now = fixedDate
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
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
        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in throw APIError.networkUnavailable }
            $0.transmissionClient = client
            $0.date.now = Date(timeIntervalSince1970: 5)
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
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
    func detailsLoadedParserFailure() async throws {
        let response = TransmissionResponse(result: "success")
        let store = TestStore(
            initialState: {
                var state = TorrentDetailReducer.State(torrentId: 1)
                state.isLoading = true
                return state
            }()
        ) {
            TorrentDetailReducer()
        } withDependencies: {
            var parser = TorrentDetailParserDependency.testValue
            parser.parse = { _ in throw TorrentDetailParserError.missingTorrentData }
            $0.torrentDetailParser = parser
        }

        let timestamp = Date(timeIntervalSince1970: 42)

        await store.send(.detailsLoaded(response, timestamp)) {
            $0.isLoading = false
            $0.errorMessage = TorrentDetailParserError.missingTorrentData.localizedDescription
        }
    }

    @Test
    func startTorrentSuccess() async throws {
        let snapshot = TorrentDetailParsedSnapshot(
            name: "Updated",
            status: 1,
            percentDone: 0.25,
            totalSize: 42,
            downloadedEver: 21,
            uploadedEver: 0,
            eta: 10,
            rateDownload: 100,
            rateUpload: 50,
            uploadRatio: 0.5,
            downloadLimit: 200,
            downloadLimited: true,
            uploadLimit: 100,
            uploadLimited: false,
            peersConnected: 2,
            peersFrom: [],
            downloadDir: "/downloads",
            dateAdded: 7,
            files: [],
            trackers: [],
            trackerStats: []
        )

        let fixedDate = Date(timeIntervalSince1970: 100)

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentStart = { _ in TransmissionResponse(result: "success") }
            client.torrentGet = { _, _ in TransmissionResponse(result: "success") }
            var parser = TorrentDetailParserDependency.testValue
            parser.parse = { _ in snapshot }
            $0.transmissionClient = client
            $0.torrentDetailParser = parser
            $0.date.now = fixedDate
        }

        await store.send(.startTorrent)
        await store.receive(.actionCompleted("Торрент запущен"))
        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.detailsLoaded(TransmissionResponse(result: "success"), fixedDate)) {
            $0.isLoading = false
            $0.name = "Updated"
            $0.status = 1
            $0.percentDone = 0.25
            $0.totalSize = 42
            $0.downloadedEver = 21
            $0.eta = 10
            $0.rateDownload = 100
            $0.rateUpload = 50
            $0.uploadRatio = 0.5
            $0.downloadLimit = 200
            $0.downloadLimited = true
            $0.uploadLimit = 100
            $0.uploadLimited = false
            $0.peersConnected = 2
            $0.downloadDir = "/downloads"
            $0.dateAdded = 7
            $0.speedHistory = [
                SpeedSample(
                    timestamp: fixedDate,
                    downloadRate: 100,
                    uploadRate: 50
                )
            ]
        }
    }

    @Test
    func startTorrentFailure() async throws {
        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentStart = { _ in throw APIError.networkUnavailable }
            $0.transmissionClient = client
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
        }

        await store.send(.startTorrent)
        await store.receive(.actionFailed("Сеть недоступна"))
    }

    @Test
    func toggleDownloadLimitSuccess() async throws {
        let snapshot = TorrentDetailParsedSnapshot(
            name: "Torrent",
            status: nil,
            percentDone: nil,
            totalSize: nil,
            downloadedEver: nil,
            uploadedEver: nil,
            eta: nil,
            rateDownload: nil,
            rateUpload: nil,
            uploadRatio: nil,
            downloadLimit: 512,
            downloadLimited: true,
            uploadLimit: nil,
            uploadLimited: nil,
            peersConnected: nil,
            peersFrom: [],
            downloadDir: nil,
            dateAdded: nil,
            files: [],
            trackers: [],
            trackerStats: []
        )

        let fixedDate = Date(timeIntervalSince1970: 200)

        let store = TestStore(
            initialState: {
                var state = TorrentDetailReducer.State(torrentId: 1)
                state.downloadLimit = 256
                state.downloadLimited = false
                return state
            }()
        ) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentSet = { _, _ in TransmissionResponse(result: "success") }
            client.torrentGet = { _, _ in TransmissionResponse(result: "success") }
            var parser = TorrentDetailParserDependency.testValue
            parser.parse = { _ in snapshot }
            $0.transmissionClient = client
            $0.torrentDetailParser = parser
            $0.date.now = fixedDate
        }

        await store.send(.toggleDownloadLimit(true)) {
            $0.downloadLimited = true
        }
        await store.receive(.actionCompleted("Настройки скоростей обновлены"))
        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.detailsLoaded(TransmissionResponse(result: "success"), fixedDate)) {
            $0.isLoading = false
            $0.name = "Torrent"
            $0.downloadLimit = 512
            $0.downloadLimited = true
            $0.speedHistory = [
                SpeedSample(timestamp: fixedDate, downloadRate: 0, uploadRate: 0)
            ]
        }
    }

    @Test
    func setPriorityUpdatesIndices() async throws {
        let baseResponse = TorrentDetailTestHelpers.makeBasicResponse()
        let responseStore = ResponseStore(responses: [baseResponse, baseResponse])
        let argumentStore = ArgumentStore()

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
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
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
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

}

// swiftlint:enable explicit_type_interface function_body_length type_body_length
