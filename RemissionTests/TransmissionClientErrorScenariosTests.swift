import Clocks
import Foundation
import Testing

@testable import Remission

private let transmissionTestsBaseURL: URL = URL(string: "http://mock.transmission/rpc")!

/// TransmissionClient negative-path coverage backed by TransmissionMockServer scenarios.
///
/// Покрывает ключевые ошибки APIError и проверяет безопасное логирование.
/// Сценарии используют declarative mock server (RTC-29) без дублирования тестовых стабаов.
///
/// **Справочные материалы (Context7):**
/// - `/pointfreeco/swift-composable-architecture` → статья *Testing TCA* (mock dependencies, TestStore).
/// - `/swiftlang/swift-testing` → *Discoverable Test Content* и best practices @Test/@Suite.
/// - `/websites/transmission-rpc_readthedocs_io` → спецификация Transmission RPC (handshake, версии).
@Suite("TransmissionClient Error Scenarios", .serialized)
@MainActor
struct TransmissionClientErrorScenariosTests {
    @Test("Останавливает handshake после двух 409 и выбрасывает sessionConflict")
    func testStopsHandshakeAfterTwo409Conflicts() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "two-409-then-fail",
                steps: [
                    .handshake(
                        sessionID: "session-1",
                        followUp: .handshake(
                            sessionID: "session-2",
                            followUp: .handshake(
                                sessionID: "session-3",
                                followUp: .rpcError(result: "unexpected")
                            )
                        )
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Expected APIError.sessionConflict after >2 handshakes")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
        } catch {
            #expect(Bool(false), "Expected APIError, got \(error)")
        }
    }

    @Test("performHandshake выбрасывает versionUnsupported при rpc-version < 14")
    func testPerformHandshakeVersionUnsupported() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "unsupported-version",
                steps: [
                    .handshake(
                        sessionID: "session-v12",
                        followUp: .rpcSuccess(
                            arguments: .object([
                                "rpc-version": .int(13),
                                "version": .string("2.94")
                            ])
                        )
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.performHandshake()
            #expect(Bool(false), "Expected versionUnsupported error")
        } catch let error as APIError {
            if case .versionUnsupported(let version) = error {
                #expect(version.contains("13") || version.contains("2.94"))
            } else {
                #expect(Bool(false), "Expected versionUnsupported, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected APIError, got \(error)")
        }
    }

    @Test("Некорректный JSON приводит к APIError.decodingFailed")
    func testInvalidJSONResponseTriggersDecodingFailed() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "invalid-json",
                steps: [
                    TransmissionMockStep(
                        matcher: .method("torrent-get"),
                        response: .http(
                            statusCode: 200,
                            headers: ["Content-Type": "application/json"],
                            body: Data("not-a-json".utf8)
                        )
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Expected decodingFailed error")
        } catch let error as APIError {
            if case .decodingFailed(let details) = error {
                #expect(details.isEmpty == false, "decodingFailed should surface context")
            } else {
                #expect(Bool(false), "Expected decodingFailed, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected APIError, got \(error)")
        }
    }

    @Test("HTTP 500 мапится в APIError.unknown")
    func testHttp500MapsToUnknown() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "http-500",
                steps: [
                    TransmissionMockStep(
                        matcher: .method("session-get"),
                        response: .http(statusCode: 500, headers: [:], body: nil)
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Expected APIError.unknown when status code != 2xx")
        } catch let error as APIError {
            #expect(error == .unknown(details: "HTTP status code: 500"))
        } catch {
            #expect(Bool(false), "Expected APIError, got \(error)")
        }
    }

    @Test("URLError(.cannotConnectToHost) превращается в networkUnavailable")
    func testNetworkFailureMapsToNetworkUnavailable() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "network-failure",
                steps: [
                    .networkFailure(
                        method: "torrent-get",
                        error: URLError(.cannotConnectToHost)
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Expected APIError.networkUnavailable")
        } catch let error as APIError {
            #expect(error == .networkUnavailable)
        } catch {
            #expect(Bool(false), "Expected APIError, got \(error)")
        }
    }

    @Test("Логирование маскирует Basic Auth и session-id")
    func testLoggingMasksSecretsDuringHandshake() async throws {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        let sessionID: String = "VERY-SECRET-SESSION-ID"
        server.register(
            scenario: .init(
                name: "logging-handshake",
                steps: [
                    .handshake(
                        method: "torrent-get",
                        sessionID: sessionID,
                        followUp: .rpcSuccess(
                            arguments: .object(["torrents": .array([])])
                        )
                    )
                ]
            )
        )

        let logs: TransmissionLogCollector = TransmissionLogCollector()
        let logger: DefaultTransmissionLogger = DefaultTransmissionLogger { message in
            logs.append(message)
        }
        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: transmissionTestsBaseURL,
            username: "user",
            password: "super-secret",
            requestTimeout: 5,
            maxRetries: 0,
            enableLogging: true,
            logger: logger
        )

        let (client, _) = makeClient(using: server, configOverride: config)
        _ = try await client.torrentGet(ids: nil, fields: nil)
        try server.assertAllScenariosFinished()

        let joinedLogs: String = logs.messages.joined(separator: "\n")
        #expect(!joinedLogs.contains("super-secret"))
        #expect(!joinedLogs.contains("dXNlcjpzdXBlci1zZWNyZXQ="))
        #expect(joinedLogs.contains("Authorization: Basic dXNl...ZXQ="))
        #expect(!joinedLogs.contains(sessionID))
    }

    @Test("Проверяет экспоненциальный backoff при сетевых ошибках")
    func testExponentialBackoffOnNetworkErrors() async throws {
        let successResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["torrents": .array([])]),
            tag: nil
        )
        let successData = try JSONEncoder().encode(successResponse)
        defer { RetryURLProtocol.reset() }

        let setup = makeRetryingClient(
            responses: [
                .error(URLError(.timedOut)),
                .error(URLError(.timedOut)),
                .error(URLError(.timedOut)),
                .success(successData)
            ],
            maxRetries: 3,
            retryDelay: 0.01
        )

        let start = ContinuousClock.now
        _ = try await setup.client.torrentGet(ids: nil, fields: nil)
        let elapsed = start.duration(to: ContinuousClock.now)

        #expect(RetryURLProtocol.requestCount == 4)
        // Минимум 0.07с (0.01 + 0.02 + 0.04) с учётом backoff, но меньше секунды.
        #expect(elapsed >= .milliseconds(60))
        #expect(elapsed < .seconds(1))
    }

    @Test("HTTP 401 при torrent-add возвращает APIError.unauthorized")
    func testTorrentAddUnauthorized() async {
        let server: TransmissionMockServer = TransmissionMockServer()
        defer { cleanupMockServer() }
        server.register(
            scenario: .init(
                name: "torrent-add unauthorized",
                steps: [
                    TransmissionMockStep(
                        matcher: .method("torrent-add"),
                        response: .http(statusCode: 401, headers: [:], body: nil)
                    )
                ]
            )
        )

        let (client, _) = makeClient(using: server)

        do {
            _ = try await client.torrentAdd(
                filename: "magnet:?xt=urn:btih:unauthorized",
                metainfo: nil,
                downloadDir: nil,
                paused: nil,
                labels: nil
            )
            #expect(Bool(false), "Ожидалась ошибка unauthorized")
        } catch let error as APIError {
            #expect(error == .unauthorized)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

}

// MARK: - Helpers

private func cleanupMockServer() {
    TransmissionMockServer.activeServerLock.lock()
    TransmissionMockServer.activeServer = nil
    TransmissionMockServer.activeServerLock.unlock()
}

private func makeClient(
    using server: TransmissionMockServer,
    configOverride: TransmissionClientConfig? = nil
) -> (client: TransmissionClient, clock: TestClock<Duration>) {
    let sessionConfiguration: URLSessionConfiguration =
        server.makeEphemeralSessionConfiguration()

    let config: TransmissionClientConfig =
        configOverride
        ?? TransmissionClientConfig(
            baseURL: transmissionTestsBaseURL,
            requestTimeout: 5,
            maxRetries: 0,
            enableLogging: false
        )
    let testClock = TestClock<Duration>()
    let client = TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        trustStore: .inMemory(),
        trustDecisionHandler: { _ in .trustPermanently },
        clock: testClock
    )
    return (client, testClock)
}

private struct RetryingClientSetup {
    var client: TransmissionClient
}

private func makeRetryingClient(
    responses: [RetryURLProtocol.Response],
    maxRetries: Int,
    retryDelay: Double
) -> RetryingClientSetup {
    RetryURLProtocol.configure(responses: responses)

    let config = TransmissionClientConfig(
        baseURL: transmissionTestsBaseURL,
        requestTimeout: 0.2,
        maxRetries: maxRetries,
        retryDelay: retryDelay
    )

    let sessionConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RetryURLProtocol.self]
        configuration.timeoutIntervalForRequest = 0.5
        configuration.timeoutIntervalForResource = 1
        return configuration
    }()

    let client = TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        trustStore: .inMemory(),
        trustDecisionHandler: { _ in .trustPermanently },
        clock: ContinuousClock()
    )

    return RetryingClientSetup(
        client: client
    )
}

private final class TransmissionLogCollector: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var storage: [String] = []

    func append(_ message: String) {
        lock.lock()
        storage.append(message)
        lock.unlock()
    }

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class RecordingClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = TestClock<Duration>.Instant

    private let base: TestClock<Duration>
    private(set) var sleepHistory: [Duration] = []

    init(base: TestClock<Duration>) {
        self.base = base
    }

    var now: Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let interval = base.now.duration(to: deadline)
        sleepHistory.append(interval)
        try await base.sleep(until: deadline, tolerance: tolerance)
    }

    func sleep(for duration: Duration, tolerance: Duration? = nil) async throws {
        sleepHistory.append(duration)
        try await base.sleep(for: duration, tolerance: tolerance)
    }
}

private class RetryURLProtocol: URLProtocol {
    enum Response {
        case error(URLError)
        case success(Data)
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var pendingResponses: [Response] = []
    private nonisolated(unsafe) static var _requestCount: Int = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    static func configure(responses: [Response]) {
        lock.lock()
        pendingResponses = responses
        lock.unlock()
    }

    static func reset() {
        configure(responses: [])
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client else { return }
        Self.incrementRequests()
        guard let next = Self.dequeue() else {
            client.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        switch next {
        case .error(let error):
            client.urlProtocol(self, didFailWithError: error)
        case .success(let data):
            guard let url = request.url else {
                client.urlProtocol(
                    self,
                    didFailWithError: URLError(.badURL)
                )
                return
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func dequeue() -> Response? {
        lock.lock()
        defer { lock.unlock() }
        guard pendingResponses.isEmpty == false else { return nil }
        return pendingResponses.removeFirst()
    }

    private static func incrementRequests() {
        lock.lock()
        _requestCount += 1
        lock.unlock()
    }
}

private func durationInSeconds(_ duration: Swift.Duration) -> Double {
    let components = duration.components
    let seconds = Double(components.seconds)
    let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
    return seconds + attoseconds
}
