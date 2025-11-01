import Clocks
import ComposableArchitecture
import Foundation
import Testing
import XCTest

@testable import Remission

// swiftlint:disable explicit_type_interface function_body_length type_body_length

private actor AsyncCounter {
    private var value: Int = 0

    func increment() {
        value += 1
    }

    func current() -> Int {
        value
    }
}

@MainActor
struct TorrentDetailFeatureTests {
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
    func loadTorrentDetailsCancelsInFlightRequests() async throws {
        let clock = TestClock()
        let callCounter = AsyncCounter()
        let timestamp = Date(timeIntervalSince1970: 20)

        let response = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Sequential Load"),
                        "status": .int(4),
                        "percentDone": .double(1.0),
                        "totalSize": .int(2048),
                        "downloadedEver": .int(2048),
                        "uploadedEver": .int(512),
                        "eta": .int(0),
                        "rateDownload": .int(600_000),
                        "rateUpload": .int(200_000),
                        "uploadRatio": .double(2.0),
                        "downloadLimit": .int(1800),
                        "downloadLimited": .bool(true),
                        "uploadLimit": .int(900),
                        "uploadLimited": .bool(true),
                        "peersConnected": .int(6),
                        "peersFrom": .object(["tracker": .int(6)]),
                        "downloadDir": .string("/downloads"),
                        "dateAdded": .int(654321),
                        "files": .array([]),
                        "trackers": .array([]),
                        "trackerStats": .array([])
                    ])
                ])
            ])
        )

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in
                await callCounter.increment()
                try await clock.sleep(for: .seconds(1))
                return response
            }
            $0.transmissionClient = client
            $0.date.now = timestamp
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
        }

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.send(.loadTorrentDetails)

        await clock.advance(by: .seconds(1))

        await store.receive(.detailsLoaded(response, timestamp)) {
            $0.isLoading = false
            $0.name = "Sequential Load"
            $0.status = 4
            $0.percentDone = 1.0
            $0.totalSize = 2048
            $0.downloadedEver = 2048
            $0.uploadedEver = 512
            $0.eta = 0
            $0.rateDownload = 600_000
            $0.rateUpload = 200_000
            $0.uploadRatio = 2.0
            $0.downloadLimit = 1800
            $0.downloadLimited = true
            $0.uploadLimit = 900
            $0.uploadLimited = true
            $0.peersConnected = 6
            $0.peersFrom = [PeerSource(name: "tracker", count: 6)]
            $0.downloadDir = "/downloads"
            $0.dateAdded = 654321
            $0.files = []
            $0.trackers = []
            $0.trackerStats = []
            $0.speedHistory = [
                SpeedSample(timestamp: timestamp, downloadRate: 600_000, uploadRate: 200_000)
            ]
        }

        #expect(await callCounter.current() == 2)
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
        let torrent = Torrent(
            id: .init(rawValue: 1),
            name: "Updated",
            status: .checkWaiting,
            summary: .init(
                progress: .init(
                    percentDone: 0.25,
                    totalSize: 42,
                    downloadedEver: 21,
                    uploadedEver: 0,
                    uploadRatio: 0.5,
                    etaSeconds: 10
                ),
                transfer: .init(
                    downloadRate: 100,
                    uploadRate: 50,
                    downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 200),
                    uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 100)
                ),
                peers: .init(connected: 2, sources: [])
            ),
            details: .init(
                downloadDirectory: "/downloads",
                addedDate: Date(timeIntervalSince1970: 7),
                files: [],
                trackers: [],
                trackerStats: [],
                speedSamples: []
            )
        )

        let fixedDate = Date(timeIntervalSince1970: 100)

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentStart = { _ in TransmissionResponse(result: "success") }
            client.torrentGet = { _, _ in TransmissionResponse(result: "success") }
            var parser = TorrentDetailParserDependency.testValue
            parser.parse = { _ in torrent }
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
        let torrent = Torrent(
            id: .init(rawValue: 1),
            name: "Torrent",
            status: .stopped,
            summary: .init(
                progress: .init(
                    percentDone: 0,
                    totalSize: 0,
                    downloadedEver: 0,
                    uploadedEver: 0,
                    uploadRatio: 0,
                    etaSeconds: 0
                ),
                transfer: .init(
                    downloadRate: 0,
                    uploadRate: 0,
                    downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 512),
                    uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 0)
                ),
                peers: .init(connected: 0, sources: [])
            ),
            details: .init(
                downloadDirectory: "",
                addedDate: nil,
                files: [],
                trackers: [],
                trackerStats: [],
                speedSamples: []
            )
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
            parser.parse = { _ in torrent }
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
                TorrentFile(
                    index: 0,
                    name: "File A",
                    length: 100,
                    bytesCompleted: 50,
                    priority: 1,
                    wanted: true
                ),
                TorrentFile(
                    index: 1,
                    name: "File B",
                    length: 200,
                    bytesCompleted: 200,
                    priority: 1,
                    wanted: true
                )
            ]
            $0.trackers = [TorrentTracker(id: 0, announce: "https://tracker/announce", tier: 0)]
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
