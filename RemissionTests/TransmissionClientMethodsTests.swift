import Clocks
import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient Torrent Methods", .serialized)
@MainActor
// swiftlint:disable:next type_body_length
struct TransmissionClientMethodsTests {
    private let baseURL = URL(string: "http://example.com/transmission/rpc")!

    // MARK: - Happy Paths

    @Test("torrent-get успешно кодирует ids/fields и парсит ответ")
    func testTorrentGetSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            responseArguments: .object(["torrents": .array([])]),
            call: { client in
                try await client.torrentGet(ids: [1, 2], fields: ["id", "name"])
            },
            validate: { request in
                #expect(request.method == "torrent-get")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(1), .int(2)]))
                #expect(arguments["fields"] == .array([.string("id"), .string("name")]))
            }
        )
    }

    @Test("torrent-get возвращает APIError при ошибке Transmission")
    func testTorrentGetError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentGet(ids: [42], fields: ["id"])
            },
            validate: { request in
                #expect(request.method == "torrent-get")
            },
            assertError: { error in
                #expect(error == .unknown(details: "too many recent requests"))
            }
        )
    }

    @Test("torrent-add отправляет опциональные параметры")
    func testTorrentAddSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentAdd(
                    filename: "magnet:?xt=urn:btih:123",
                    metainfo: nil,
                    downloadDir: "/downloads",
                    paused: true,
                    labels: ["tv", "1080p"]
                )
            },
            validate: { request in
                #expect(request.method == "torrent-add")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["filename"] == .string("magnet:?xt=urn:btih:123"))
                #expect(arguments["download-dir"] == .string("/downloads"))
                #expect(arguments["paused"] == .bool(true))
                #expect(arguments["labels"] == .array([.string("tv"), .string("1080p")]))
            }
        )
    }

    @Test("torrent-add пробрасывает APIError из ответа")
    func testTorrentAddError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentAdd(
                    filename: "magnet:?xt=urn:btih:error",
                    metainfo: nil,
                    downloadDir: nil,
                    paused: nil,
                    labels: nil
                )
            },
            validate: { request in
                #expect(request.method == "torrent-add")
            },
            assertError: { error in
                #expect(error == .unknown(details: "duplicate torrent"))
            },
            failureResult: "duplicate torrent"
        )
    }

    @Test("torrent-add кодирует metainfo в base64 и не добавляет filename")
    func testTorrentAddMetainfoEncoding() async throws {
        let payload = Data([0x00, 0x01, 0xFF])

        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentAdd(
                    filename: nil,
                    metainfo: payload,
                    downloadDir: nil,
                    paused: nil,
                    labels: nil
                )
            },
            validate: { request in
                #expect(request.method == "torrent-add")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["metainfo"] == .string(payload.base64EncodedString()))
                #expect(arguments["filename"] == nil)
            }
        )
    }

    @Test("torrent-add требует filename или metainfo")
    func testTorrentAddRequiresSource() async throws {
        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.torrentAdd(
                filename: nil,
                metainfo: nil,
                downloadDir: nil,
                paused: nil,
                labels: nil
            )
            #expect(Bool(false), "Ожидалась ошибка при отсутствии источника торрента")
        } catch let error as APIError {
            #expect(error == .unknown(details: "torrent-add requires filename or metainfo"))
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("TransmissionClient добавляет Basic Auth заголовок при наличии credentials")
    func testAuthorizationHeaderIsInjected() async throws {
        let expectedResponse = TransmissionResponse(result: "success")
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(expectedResponse)
                return (response, data)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            username: "user",
            password: "pass"
        )
        let (client, _) = makeTransmissionClient(baseURL: baseURL, config: config)
        let response = try await client.sessionStats()
        #expect(response == expectedResponse)

        let request = try #require(MockURLProtocol.requests.last)
        let header = try #require(request.value(forHTTPHeaderField: "Authorization"))
        let expectedHeader = "Basic \(Data("user:pass".utf8).base64EncodedString())"
        #expect(header == expectedHeader)
    }

    @Test("Authorization сохраняется при повторе запроса после 409")
    func testAuthorizationPersistsAfter409Retry() async throws {
        let expectedResponse = TransmissionResponse(result: "success")
        var recordedHeaders: [String?] = []

        MockURLProtocol.setHandlers([
            { request in
                recordedHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-42"]
                )!
                return (response, Data())
            },
            { request in
                recordedHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(expectedResponse)
                return (response, data)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            username: "alice",
            password: "secret"
        )
        let (client, _) = makeTransmissionClient(baseURL: baseURL, config: config)
        let response = try await client.sessionGet()
        #expect(response == expectedResponse)

        #expect(recordedHeaders.count == 2)
        let expectedHeader = "Basic \(Data("alice:secret".utf8).base64EncodedString())"
        for header in recordedHeaders {
            let value = try #require(header)
            #expect(value == expectedHeader)
        }

        let requests = MockURLProtocol.requests
        #expect(requests.count == 2)
        let secondSessionHeader = requests.last?.value(
            forHTTPHeaderField: "X-Transmission-Session-Id")
        #expect(secondSessionHeader == "session-42")
    }

    @Test("torrent-start кодирует список идентификаторов")
    func testTorrentStartSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentStart(ids: [5, 6, 7])
            },
            validate: { request in
                #expect(request.method == "torrent-start")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(5), .int(6), .int(7)]))
            }
        )
    }

    @Test("torrent-start возвращает ошибку Transmission")
    func testTorrentStartError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentStart(ids: [999])
            },
            validate: { request in
                #expect(request.method == "torrent-start")
            },
            assertError: { error in
                #expect(error == .unknown(details: "too many torrents"))
            },
            failureResult: "too many torrents"
        )
    }

    @Test("torrent-stop кодирует список идентификаторов")
    func testTorrentStopSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentStop(ids: [11])
            },
            validate: { request in
                #expect(request.method == "torrent-stop")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(11)]))
            }
        )
    }

    @Test("torrent-stop возвращает ошибку Transmission")
    func testTorrentStopError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentStop(ids: [12])
            },
            validate: { request in
                #expect(request.method == "torrent-stop")
            },
            assertError: { error in
                #expect(error == .unknown(details: "not stopping"))
            },
            failureResult: "not stopping"
        )
    }

    @Test("torrent-remove кодирует delete-local-data")
    func testTorrentRemoveSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentRemove(ids: [20, 21], deleteLocalData: true)
            },
            validate: { request in
                #expect(request.method == "torrent-remove")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(20), .int(21)]))
                #expect(arguments["delete-local-data"] == .bool(true))
            }
        )
    }

    @Test("torrent-remove возвращает ошибку Transmission")
    func testTorrentRemoveError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentRemove(ids: [42], deleteLocalData: false)
            },
            validate: { request in
                #expect(request.method == "torrent-remove")
            },
            assertError: { error in
                #expect(error == .unknown(details: "permission denied"))
            },
            failureResult: "permission denied"
        )
    }

    @Test("torrent-set объединяет ids и переданные аргументы")
    func testTorrentSetSuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentSet(
                    ids: [77],
                    arguments: .object(["priority": .string("high"), "ratio-limit": .double(2.5)])
                )
            },
            validate: { request in
                #expect(request.method == "torrent-set")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(77)]))
                #expect(arguments["priority"] == .string("high"))
                #expect(arguments["ratio-limit"] == .double(2.5))
            }
        )
    }

    @Test("torrent-set пробрасывает ошибку Transmission")
    func testTorrentSetError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentSet(ids: [88], arguments: .object([:]))
            },
            validate: { request in
                #expect(request.method == "torrent-set")
            },
            assertError: { error in
                #expect(error == .unknown(details: "bad request"))
            },
            failureResult: "bad request"
        )
    }

    @Test("torrent-verify кодирует ids")
    func testTorrentVerifySuccess() async throws {
        try await runTransmissionSuccessTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentVerify(ids: [101, 102])
            },
            validate: { request in
                #expect(request.method == "torrent-verify")
                let arguments = try #require(request.arguments?.objectValue)
                #expect(arguments["ids"] == .array([.int(101), .int(102)]))
            }
        )
    }

    @Test("torrent-verify пробрасывает ошибку Transmission")
    func testTorrentVerifyError() async throws {
        try await runTransmissionErrorTest(
            baseURL: baseURL,
            call: { client in
                try await client.torrentVerify(ids: [999])
            },
            validate: { request in
                #expect(request.method == "torrent-verify")
            },
            assertError: { error in
                #expect(error == .unknown(details: "verify queued"))
            },
            failureResult: "verify queued"
        )
    }
}
