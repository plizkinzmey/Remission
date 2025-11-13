import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper")
struct TransmissionDomainMapperTests {
    private let mapper: TransmissionDomainMapper = .init()

    @Test("mapTorrentDetails возвращает ожидаемую доменную модель")
    func mapTorrentDetailsSuccess() throws {
        let response: TransmissionResponse = TorrentDetailTestHelpers.makeParserResponse()
        let expected: Torrent = TorrentDetailTestHelpers.makeParsedTorrent()

        let torrent: Torrent = try mapper.mapTorrentDetails(from: response)

        #expect(torrent == expected)
    }

    @Test("mapTorrentDetails выбрасывает missingTorrentData при пустом массиве")
    func mapTorrentDetailsMissing() {
        let response: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        #expect(
            throws: DomainMappingError.emptyCollection(context: "torrent-get"),
            performing: { try mapper.mapTorrentDetails(from: response) }
        )
    }

    @Test("mapTorrentList выбрасывает ошибку при неподдерживаемом статусе")
    func mapTorrentListUnsupportedStatus() {
        let response: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "torrents": .array([
                    .object([
                        "id": .int(1),
                        "name": .string("Broken"),
                        "status": .int(99),
                        "percentDone": .double(0)
                    ])
                ])
            ])
        )

        #expect(
            throws: DomainMappingError.unsupportedStatus(rawValue: 99),
            performing: { try mapper.mapTorrentList(from: response) }
        )
    }

    @Test("mapTorrentList возвращает массив с данными торрентов")
    func mapTorrentListSuccess() throws {
        let response: TransmissionResponse = try TransmissionFixture.response(
            .torrentGetSingleActive
        )

        let torrents: [Torrent] = try mapper.mapTorrentList(from: response)

        #expect(torrents.count == 1)
        let torrent: Torrent = try #require(torrents.first)
        #expect(torrent.id.rawValue == 7)
        #expect(torrent.name == "Ubuntu 24.04 LTS")
        #expect(torrent.status == .downloading)
        #expect(torrent.summary.progress.percentDone == 1.0)
        #expect(torrent.details == nil)
    }

    @Test("mapTorrentList корректно обрабатывает пустой массив")
    func mapTorrentListEmpty() throws {
        let response: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])])
        )

        let torrents: [Torrent] = try mapper.mapTorrentList(from: response)

        #expect(torrents.isEmpty)
    }

    @Test("mapTorrentList выбрасывает rpcError при ответе result != success")
    func mapTorrentListRpcError() {
        let response: TransmissionResponse = TransmissionResponse(result: "error: unauthorized")

        #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "torrent-get"
            ),
            performing: {
                _ = try mapper.mapTorrentList(from: response)
            }
        )
    }

    @Test("mapSessionState объединяет данные session-get и session-stats")
    func mapSessionStateSuccess() throws {
        let sessionResponse: TransmissionResponse = Self.makeSessionGetResponse()
        let statsResponse: TransmissionResponse = Self.makeSessionStatsResponse()

        let state: SessionState = try mapper.mapSessionState(
            sessionResponse: sessionResponse,
            statsResponse: statsResponse
        )

        #expect(state.rpc.rpcVersion == 17)
        #expect(state.speedLimits.download.isEnabled)
        #expect(state.speedLimits.download.kilobytesPerSecond == 8192)
        #expect(state.queue.downloadLimit.count == 5)
        #expect(state.throughput.totalTorrentCount == 10)
        #expect(state.cumulativeStats.filesAdded == 120)
        #expect(state.currentStats.downloadedBytes == 120_000_000)
    }

    @Test("mapSessionState падает если session-get вернул ошибку")
    func mapSessionStateRpcError() {
        let sessionResponse: TransmissionResponse = TransmissionResponse(
            result: "error: unauthorized"
        )
        let statsResponse: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([:])
        )

        #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "session-get"
            ),
            performing: {
                try mapper.mapSessionState(
                    sessionResponse: sessionResponse,
                    statsResponse: statsResponse
                )
            }
        )
    }

    @Test("mapServerConfig корректно собирает доменную модель")
    func mapServerConfigSuccess() throws {
        let record: StoredServerConfigRecord = StoredServerConfigRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            name: "Seedbox",
            host: "seedbox.example.com",
            port: 443,
            path: "/transmission/rpc",
            isSecure: true,
            allowUntrustedCertificates: false,
            username: "seeduser",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let credentials: TransmissionServerCredentials = TransmissionServerCredentials(
            key: TransmissionServerCredentialsKey(
                host: "seedbox.example.com",
                port: 443,
                isSecure: true,
                username: "seeduser"
            ),
            password: "secret"
        )

        let config: ServerConfig = try mapper.mapServerConfig(
            record: record,
            credentials: credentials
        )

        #expect(config.name == "Seedbox")
        #expect(config.connection.host == "seedbox.example.com")
        #expect(config.isSecure)
        let auth: ServerConfig.Authentication = try #require(config.authentication)
        #expect(auth.username == "seeduser")
        #expect(auth.credentialKey == credentials.key)
    }

    @Test("mapServerConfig выбрасывает ошибку если credentials не соответствуют записи")
    func mapServerConfigMismatchedCredentials() {
        let record: StoredServerConfigRecord = StoredServerConfigRecord(
            id: UUID(),
            name: "NAS",
            host: "nas.local",
            port: 9091,
            path: nil,
            isSecure: false,
            allowUntrustedCertificates: false,
            username: "admin",
            createdAt: nil
        )
        let credentials: TransmissionServerCredentials = TransmissionServerCredentials(
            key: TransmissionServerCredentialsKey(
                host: "seedbox.example.com",
                port: 443,
                isSecure: true,
                username: "seeduser"
            ),
            password: "secret"
        )

        #expect(
            throws: DomainMappingError.invalidValue(
                field: "credentials",
                description: "ключ не соответствует сохранённым настройкам сервера",
                context: "server-config"
            ),
            performing: {
                _ = try mapper.mapServerConfig(
                    record: record,
                    credentials: credentials
                )
            }
        )
    }
}

extension TransmissionDomainMapperTests {
    fileprivate static func makeSessionGetResponse() -> TransmissionResponse {
        TransmissionResponse(
            result: "success",
            arguments: .object([
                "rpc-version": .int(17),
                "rpc-version-minimum": .int(14),
                "version": .string("4.0.3"),
                "speed-limit-down-enabled": .bool(true),
                "speed-limit-down": .int(8192),
                "speed-limit-up-enabled": .bool(false),
                "speed-limit-up": .int(2048),
                "alt-speed-enabled": .bool(true),
                "alt-speed-down": .int(4096),
                "alt-speed-up": .int(1024),
                "download-queue-enabled": .bool(true),
                "download-queue-size": .int(5),
                "seed-queue-enabled": .bool(true),
                "seed-queue-size": .int(3),
                "queue-stalled-enabled": .bool(true),
                "queue-stalled-minutes": .int(30)
            ])
        )
    }

    fileprivate static func makeSessionStatsResponse() -> TransmissionResponse {
        TransmissionResponse(
            result: "success",
            arguments: .object([
                "activeTorrentCount": .int(4),
                "pausedTorrentCount": .int(2),
                "torrentCount": .int(10),
                "downloadSpeed": .int(1_200_000),
                "uploadSpeed": .int(600_000),
                "cumulative-stats": .object([
                    "filesAdded": .int(120),
                    "downloadedBytes": .int(5_120_000_000),
                    "uploadedBytes": .int(7_680_000_000),
                    "sessionCount": .int(450),
                    "secondsActive": .int(9_600)
                ]),
                "current-stats": .object([
                    "filesAdded": .int(2),
                    "downloadedBytes": .int(120_000_000),
                    "uploadedBytes": .int(340_000_000),
                    "sessionCount": .int(1),
                    "secondsActive": .int(3600)
                ])
            ])
        )
    }
}
