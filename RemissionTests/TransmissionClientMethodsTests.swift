import Foundation
import Testing

@testable import Remission

/// TransmissionClient методы тестирование — Happy Path и Error scenarios
///
/// Используется Swift Testing фреймворк с `@Test` и `@Suite` атрибутами.
/// Тесты покрывают все публичные методы API: torrent-get, torrent-add, torrent-start,
/// torrent-stop, torrent-remove, torrent-set, torrent-verify, session-* методы.
///
/// **Справочные материалы:**
/// - Swift Testing: https://developer.apple.com/documentation/testing
/// - Transmission RPC: devdoc/TRANSMISSION_RPC_REFERENCE.md
/// - TCA Testing: https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/Testing.md
///
/// **Используемые мок-компоненты:**
/// - `MockURLProtocol` — перехват URLSession запросов
/// - `TransmissionRequest`, `TransmissionResponse` — DTO парсинг
///
// swiftlint:disable explicit_type_interface file_length type_body_length
@Suite("TransmissionClient Torrent Methods")
@MainActor
struct TransmissionClientMethodsTests {
    private let baseURL = URL(string: "http://example.com/transmission/rpc")!

    // MARK: - Happy Paths

    @Test("torrent-get успешно кодирует ids/fields и парсит ответ")
    func testTorrentGetSuccess() async throws {
        try await runSuccessTest(
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
        try await runErrorTest(
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
        try await runSuccessTest(
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
        try await runErrorTest(
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

        try await runSuccessTest(
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
        MockURLProtocol.setHandlers([])
        let client = makeClient()

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

    @Test("torrent-start кодирует список идентификаторов")
    func testTorrentStartSuccess() async throws {
        try await runSuccessTest(
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
        try await runErrorTest(
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
        try await runSuccessTest(
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
        try await runErrorTest(
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
        try await runSuccessTest(
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
        try await runErrorTest(
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
        try await runSuccessTest(
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
        try await runErrorTest(
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
        try await runSuccessTest(
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
        try await runErrorTest(
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

    // MARK: - Error Handling

    @Test("возвращает decodingFailed при пустом ответе")
    func testEmptyResponseBodyProducesDecodingFailed() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
        ])

        let client = makeClient()

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка decodingFailed при пустом ответе")
        } catch let error as APIError {
            if case .decodingFailed(let message) = error {
                #expect(message == "Empty response body")
            } else {
                #expect(Bool(false), "Ожидалась decodingFailed, получено \(error)")
            }
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("маппит DecodingError в APIError.decodingFailed")
    func testInvalidJSONMapsToDecodingFailed() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("not-json".utf8))
            }
        ])

        let client = makeClient()

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка decodingFailed при невалидном JSON")
        } catch let error as APIError {
            if case .decodingFailed(let message) = error {
                #expect(message.contains("Data corrupted") || message.contains("Cannot decode"))
            } else {
                #expect(Bool(false), "Ожидалась decodingFailed, получено \(error)")
            }
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("ретраит запрос при session-conflict и использует session-id")
    func testSessionConflictRetry() async throws {
        let sessionResponse = TransmissionResponse(result: "success")

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-123"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(sessionResponse)
                return (response, data)
            }
        ])

        let client = makeClient()
        let response = try await client.torrentStart(ids: [1])
        #expect(response == sessionResponse)
        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-123")
    }

    @Test("session-conflict обрабатывается даже при maxRetries = 0")
    func testSessionConflictRetryWithoutAdditionalRetries() async throws {
        let sessionResponse = TransmissionResponse(result: "success")

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-456"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(sessionResponse)
                return (response, data)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            maxRetries: 0
        )
        let client = makeClient(config: config)
        let response = try await client.sessionStats()
        #expect(response == sessionResponse)
        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-456")
    }

    @Test("session-conflict без заголовка session-id приводит к ошибке")
    func testSessionConflictMissingHeader() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: [:]
                )!
                return (response, Data())
            }
        ])

        let client = makeClient()

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Ожидалась APIError.sessionConflict при отсутствии заголовка")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
            #expect(MockURLProtocol.requests.count == 1)
        } catch {
            #expect(Bool(false), "Ожидалась APIError.sessionConflict, получено \(error)")
        }
    }

    @Test("ограничивает количество handshake ретраев при повторных 409")
    func testSessionConflictHandshakeLimit() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-1"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-2"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-3"]
                )!
                return (response, Data())
            }
        ])

        let client = makeClient()

        do {
            _ = try await client.sessionStats()
            #expect(Bool(false), "Ожидалась APIError.sessionConflict после двух ретраев")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
            #expect(MockURLProtocol.requests.count == 3)
        } catch {
            #expect(Bool(false), "Ожидалась APIError.sessionConflict, получено \(error)")
        }
    }

    @Test("performHandshake возвращает результат после успешного рукопожатия")
    func testPerformHandshakeSuccess() async throws {
        let handshakePayload: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "rpc-version": .int(17),
                "rpc-version-minimum": .int(14),
                "version": .string("4.0.0")
            ])
        )

        MockURLProtocol.setHandlers([
            { _ in
                let response = HTTPURLResponse(
                    url: baseURL,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-handshake"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(handshakePayload)
                return (response, data)
            }
        ])

        let client = makeClient()
        let result = try await client.performHandshake()

        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-handshake")
        #expect(result.sessionID == "session-handshake")
        #expect(result.rpcVersion == 17)
        #expect(result.isCompatible == true)
        #expect(result.serverVersionDescription == "4.0.0")
    }

    @Test("performHandshake выбрасывает versionUnsupported при старой версии")
    func testPerformHandshakeVersionUnsupported() async throws {
        let handshakePayload: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "rpc-version": .int(13),
                "version": .string("2.94")
            ])
        )

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(handshakePayload)
                return (response, data)
            }
        ])

        let client = makeClient()

        do {
            _ = try await client.performHandshake()
            Issue.record("Ожидалась версия unsupported")
        } catch let error as APIError {
            if case .versionUnsupported(let version) = error {
                #expect(version.contains("2.94") || version.contains("13"))
            } else {
                Issue.record("Ожидалась APIError.versionUnsupported, получено \(error)")
            }
        }
    }

    @Test("ограничивает ретраи для не повторяемых URLError")
    func testNonRetryableURLError() async throws {
        MockURLProtocol.setHandlers([
            { _ in
                throw URLError(.unsupportedURL)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            requestTimeout: 5,
            maxRetries: 3,
            retryDelay: 0.01
        )
        let client = makeClient(config: config)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка при URLError(.unsupportedURL)")
        } catch let error as APIError {
            let expectedError = APIError.mapURLError(URLError(.unsupportedURL))
            #expect(error == expectedError)
            #expect(MockURLProtocol.requests.count == 1)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("ретраит временные URLError и в итоге пробрасывает APIError")
    func testRetryableURLErrorExhaustsRetries() async throws {
        var attempt = 0
        MockURLProtocol.setHandlers([
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            requestTimeout: 5,
            maxRetries: 3,
            retryDelay: 0.001
        )
        let client = makeClient(config: config)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка после исчерпания ретраев")
        } catch let error as APIError {
            #expect(error == .networkUnavailable)
            #expect(attempt == 4)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    // MARK: - Helpers

    private func runSuccessTest(
        responseArguments: AnyCodable? = nil,
        call: @Sendable (TransmissionClient) async throws -> TransmissionResponse,
        validate: (TransmissionRequest) throws -> Void
    ) async throws {
        let expectedResponse = TransmissionResponse(result: "success", arguments: responseArguments)

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

        let client = makeClient()
        let response = try await call(client)
        #expect(response == expectedResponse)

        let request = try #require(MockURLProtocol.requests.last)
        try validate(decodeTransmissionRequest(from: request))
    }

    private func runErrorTest(
        call: @Sendable (TransmissionClient) async throws -> TransmissionResponse,
        validate: (TransmissionRequest) throws -> Void,
        assertError: (APIError) -> Void,
        failureResult: String = "too many recent requests"
    ) async throws {
        let failureResponse = TransmissionResponse(result: failureResult)

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(failureResponse)
                return (response, data)
            }
        ])

        let client = makeClient()

        do {
            _ = try await call(client)
            #expect(Bool(false), "Ожидалась APIError, но метод завершился успешно")
        } catch let error as APIError {
            let request = try #require(MockURLProtocol.requests.last)
            try validate(decodeTransmissionRequest(from: request))
            assertError(error)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    private func makeClient(config: TransmissionClientConfig? = nil) -> TransmissionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: configuration)
        let effectiveConfig = config ?? TransmissionClientConfig(baseURL: baseURL)
        return TransmissionClient(config: effectiveConfig, session: session)
    }

    private func decodeTransmissionRequest(from request: URLRequest) throws -> TransmissionRequest {
        let data = try #require(request.httpBody, "У запроса отсутствует тело")
        return try JSONDecoder().decode(TransmissionRequest.self, from: data)
    }
}

// MARK: - Mock URL Protocol

// swiftlint:disable static_over_final_class
private final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) private static var handlers: [Handler] = []
    nonisolated(unsafe) private static var handlerIndex: Int = 0
    private static let lock: NSLock = NSLock()

    nonisolated(unsafe) private static var storedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    static func setHandlers(_ newHandlers: [Handler]) {
        lock.lock()
        defer { lock.unlock() }
        handlers = newHandlers
        handlerIndex = 0
        storedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client = client else { return }

        let handler: Handler? = {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            guard Self.handlerIndex < Self.handlers.count else { return nil }
            let current = Self.handlers[Self.handlerIndex]
            Self.handlerIndex += 1
            return current
        }()

        let normalizedRequest = Self.normalize(request)

        Self.lock.lock()
        Self.storedRequests.append(normalizedRequest)
        Self.lock.unlock()

        guard let handler else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(normalizedRequest)
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if data.isEmpty == false {
                client.urlProtocol(self, didLoad: data)
            }
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func normalize(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else {
            return request
        }

        var data = Data()
        stream.open()
        defer { stream.close() }

        let bufferCapacity = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferCapacity)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let length = stream.read(buffer, maxLength: bufferCapacity)
            if length > 0 {
                data.append(buffer, count: length)
            } else {
                break
            }
        }

        var mutableRequest = request
        mutableRequest.httpBody = data
        return mutableRequest
    }
}
// swiftlint:enable static_over_final_class
// swiftlint:enable explicit_type_interface file_length type_body_length
