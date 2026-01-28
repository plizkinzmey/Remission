import ComposableArchitecture
import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClientDependency Tests")
struct TransmissionClientDependencyTests {
    // Проверяет, что стандартная test-зависимость явно падает,
    // если её не переопределили в тесте.
    @Test
    func defaultTestDependencyThrowsNotConfigured() async throws {
        let dependencies = DependencyValues()

        await #expect(throws: TransmissionClientDependencyError.self) {
            _ = try await dependencies.transmissionClient.sessionGet()
        }
    }

    // Проверяет, что live(client:) корректно проксирует вызовы
    // к реальному TransmissionClientProtocol и возвращает его результат.
    @Test
    func liveClientForwardsSessionGet() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(sessionGetResponse: expected)
        let dependency = TransmissionClientDependency.live(client: client)

        let response = try await dependency.sessionGet()

        #expect(response == expected)
        #expect(client.sessionGetCallCount == 1)
    }

    // Проверяет, что live(client:) проксирует аргументы session-set без потерь.
    @Test
    func liveClientForwardsSessionSetArguments() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(sessionSetResponse: expected)
        let dependency = TransmissionClientDependency.live(client: client)
        let arguments: AnyCodable = .object(["speed-limit-down": .int(1000)])

        _ = try await dependency.sessionSet(arguments)

        let recorded = client.lastSessionSetArguments
        #expect(recorded == arguments)
    }

    // Проверяет, что live(client:) проксирует параметры torrent-get (ids и fields).
    @Test
    func liveClientForwardsTorrentGetParameters() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(torrentGetResponse: expected)
        let dependency = TransmissionClientDependency.live(client: client)

        let ids = [1, 2, 3]
        let fields = ["id", "name"]

        _ = try await dependency.torrentGet(ids, fields)

        #expect(client.lastTorrentGetIDs == ids)
        #expect(client.lastTorrentGetFields == fields)
    }

    // Проверяет, что live(client:) проксирует все параметры torrent-add,
    // включая опциональные значения.
    @Test
    func liveClientForwardsTorrentAddParameters() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(torrentAddResponse: expected)
        let dependency = TransmissionClientDependency.live(client: client)

        let filename = "magnet:?xt=urn:btih:example"
        let metainfo = Data([0x01, 0x02])
        let downloadDir = "/downloads"
        let paused = true
        let labels = ["movies", "linux"]

        _ = try await dependency.torrentAdd(filename, metainfo, downloadDir, paused, labels)

        #expect(client.lastTorrentAddFilename == filename)
        #expect(client.lastTorrentAddMetainfo == metainfo)
        #expect(client.lastTorrentAddDownloadDir == downloadDir)
        #expect(client.lastTorrentAddPaused == paused)
        #expect(client.lastTorrentAddLabels == labels)
    }

    // Проверяет проксирование команд управления торрентами (start/stop/remove/verify).
    @Test
    func liveClientForwardsTorrentLifecycleCommands() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(
            torrentStartResponse: expected,
            torrentStopResponse: expected,
            torrentRemoveResponse: expected,
            torrentVerifyResponse: expected
        )
        let dependency = TransmissionClientDependency.live(client: client)

        let ids = [42, 99]
        _ = try await dependency.torrentStart(ids)
        _ = try await dependency.torrentStop(ids)
        _ = try await dependency.torrentRemove(ids, true)
        _ = try await dependency.torrentVerify(ids)

        #expect(client.lastTorrentStartIDs == ids)
        #expect(client.lastTorrentStopIDs == ids)
        #expect(client.lastTorrentRemoveIDs == ids)
        #expect(client.lastTorrentRemoveDeleteLocalData == true)
        #expect(client.lastTorrentVerifyIDs == ids)
    }

    // Проверяет проксирование torrent-set: ids и arguments должны дойти без изменений.
    @Test
    func liveClientForwardsTorrentSetArguments() async throws {
        let expected = TransmissionResponse(result: "success")
        let client = MockTransmissionClient(torrentSetResponse: expected)
        let dependency = TransmissionClientDependency.live(client: client)

        let ids = [7]
        let arguments: AnyCodable = .object(["queue-position": .int(1)])

        _ = try await dependency.torrentSet(ids, arguments)

        #expect(client.lastTorrentSetIDs == ids)
        #expect(client.lastTorrentSetArguments == arguments)
    }

    // Проверяет проксирование методов проверки версии и рукопожатия.
    @Test
    func liveClientForwardsVersionChecksAndHandshake() async throws {
        let expectedHandshake = TransmissionHandshakeResult(
            sessionID: "session-id",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.5",
            isCompatible: true
        )
        let client = MockTransmissionClient(
            checkServerVersionResponse: (true, 20),
            handshakeResponse: expectedHandshake
        )
        let dependency = TransmissionClientDependency.live(client: client)

        let version = try await dependency.checkServerVersion()
        let handshake = try await dependency.performHandshake()

        #expect(version.compatible)
        #expect(version.rpcVersion == 20)
        #expect(handshake == expectedHandshake)
        #expect(client.checkServerVersionCallCount == 1)
        #expect(client.performHandshakeCallCount == 1)
    }

    // Проверяет, что setTrustDecisionHandler действительно прокидывает хендлер в клиент.
    @Test
    func liveClientForwardsTrustDecisionHandler() async throws {
        let client = MockTransmissionClient()
        let dependency = TransmissionClientDependency.live(client: client)

        dependency.setTrustDecisionHandler { _ in .deny }

        #expect(client.didSetTrustDecisionHandler)
    }
}

// MARK: - Test Double

private final class MockTransmissionClient: TransmissionClientProtocol, @unchecked Sendable {
    // MARK: Configured responses

    var sessionGetResponse: TransmissionResponse
    var sessionSetResponse: TransmissionResponse
    var sessionStatsResponse: TransmissionResponse
    var freeSpaceResponse: TransmissionResponse
    var torrentGetResponse: TransmissionResponse
    var torrentAddResponse: TransmissionResponse
    var torrentStartResponse: TransmissionResponse
    var torrentStopResponse: TransmissionResponse
    var torrentRemoveResponse: TransmissionResponse
    var torrentSetResponse: TransmissionResponse
    var torrentVerifyResponse: TransmissionResponse
    var checkServerVersionResponse: (compatible: Bool, rpcVersion: Int)
    var handshakeResponse: TransmissionHandshakeResult

    // MARK: Recorded calls

    var sessionGetCallCount = 0
    var sessionSetCallCount = 0
    var checkServerVersionCallCount = 0
    var performHandshakeCallCount = 0

    var lastSessionSetArguments: AnyCodable?
    var lastTorrentGetIDs: [Int]?
    var lastTorrentGetFields: [String]?

    var lastTorrentAddFilename: String?
    var lastTorrentAddMetainfo: Data?
    var lastTorrentAddDownloadDir: String?
    var lastTorrentAddPaused: Bool?
    var lastTorrentAddLabels: [String]?

    var lastTorrentStartIDs: [Int]?
    var lastTorrentStopIDs: [Int]?
    var lastTorrentRemoveIDs: [Int]?
    var lastTorrentRemoveDeleteLocalData: Bool?
    var lastTorrentSetIDs: [Int]?
    var lastTorrentSetArguments: AnyCodable?
    var lastTorrentVerifyIDs: [Int]?

    var didSetTrustDecisionHandler = false

    init(
        sessionGetResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        sessionSetResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        sessionStatsResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        freeSpaceResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentGetResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentAddResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentStartResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentStopResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentRemoveResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentSetResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        torrentVerifyResponse: TransmissionResponse = TransmissionResponse(result: "success"),
        checkServerVersionResponse: (compatible: Bool, rpcVersion: Int) = (true, 20),
        handshakeResponse: TransmissionHandshakeResult = TransmissionHandshakeResult(
            sessionID: nil,
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: nil,
            isCompatible: true
        )
    ) {
        self.sessionGetResponse = sessionGetResponse
        self.sessionSetResponse = sessionSetResponse
        self.sessionStatsResponse = sessionStatsResponse
        self.freeSpaceResponse = freeSpaceResponse
        self.torrentGetResponse = torrentGetResponse
        self.torrentAddResponse = torrentAddResponse
        self.torrentStartResponse = torrentStartResponse
        self.torrentStopResponse = torrentStopResponse
        self.torrentRemoveResponse = torrentRemoveResponse
        self.torrentSetResponse = torrentSetResponse
        self.torrentVerifyResponse = torrentVerifyResponse
        self.checkServerVersionResponse = checkServerVersionResponse
        self.handshakeResponse = handshakeResponse
    }

    func sessionGet() async throws -> TransmissionResponse {
        sessionGetCallCount += 1
        return sessionGetResponse
    }

    func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        sessionSetCallCount += 1
        lastSessionSetArguments = arguments
        return sessionSetResponse
    }

    func sessionStats() async throws -> TransmissionResponse {
        sessionStatsResponse
    }

    func freeSpace(path: String) async throws -> TransmissionResponse {
        _ = path
        return freeSpaceResponse
    }

    func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
        lastTorrentGetIDs = ids
        lastTorrentGetFields = fields
        return torrentGetResponse
    }

    func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> TransmissionResponse {
        lastTorrentAddFilename = filename
        lastTorrentAddMetainfo = metainfo
        lastTorrentAddDownloadDir = downloadDir
        lastTorrentAddPaused = paused
        lastTorrentAddLabels = labels
        return torrentAddResponse
    }

    func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        lastTorrentStartIDs = ids
        return torrentStartResponse
    }

    func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        lastTorrentStopIDs = ids
        return torrentStopResponse
    }

    func torrentRemove(ids: [Int], deleteLocalData: Bool?) async throws -> TransmissionResponse {
        lastTorrentRemoveIDs = ids
        lastTorrentRemoveDeleteLocalData = deleteLocalData
        return torrentRemoveResponse
    }

    func torrentSet(ids: [Int], arguments: AnyCodable) async throws -> TransmissionResponse {
        lastTorrentSetIDs = ids
        lastTorrentSetArguments = arguments
        return torrentSetResponse
    }

    func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        lastTorrentVerifyIDs = ids
        return torrentVerifyResponse
    }

    func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
        checkServerVersionCallCount += 1
        return checkServerVersionResponse
    }

    func performHandshake() async throws -> TransmissionHandshakeResult {
        performHandshakeCallCount += 1
        return handshakeResponse
    }

    func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {
        _ = handler
        didSetTrustDecisionHandler = true
    }
}
