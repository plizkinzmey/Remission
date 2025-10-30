import Clocks
import Foundation
import Testing

@testable import Remission

/// TransmissionClient negative-path coverage backed by TransmissionMockServer scenarios.
///
/// Покрывает ключевые ошибки APIError и проверяет безопасное логирование.
/// Сценарии используют declarative mock server (RTC-29) без дублирования тестовых стабаов.
///
/// **Справочные материалы (Context7):**
/// - `/pointfreeco/swift-composable-architecture` → статья *Testing TCA* (mock dependencies, TestStore).
/// - `/swiftlang/swift-testing` → *Discoverable Test Content* и best practices @Test/@Suite.
/// - `/websites/transmission-rpc_readthedocs_io` → спецификация Transmission RPC (handshake, версии).
@Suite("TransmissionClient Error Scenarios")
@MainActor
struct TransmissionClientErrorScenariosTests {
    private let baseURL: URL = URL(string: "https://mock.transmission/rpc")!

    @Test("Останавливает handshake после двух 409 и выбрасывает sessionConflict")
    func testStopsHandshakeAfterTwo409Conflicts() async {
        let server: TransmissionMockServer = TransmissionMockServer()
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
            baseURL: baseURL,
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
        let server = TransmissionMockServer()
        server.register(
            scenario: .init(
                name: "retry-with-backoff",
                steps: [
                    .networkFailure(method: "torrent-get", error: URLError(.timedOut)),
                    .networkFailure(method: "torrent-get", error: URLError(.timedOut)),
                    .networkFailure(method: "torrent-get", error: URLError(.timedOut)),
                    .rpcSuccess(
                        method: "torrent-get", arguments: .object(["torrents": .array([])]))
                ]
            )
        )

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            requestTimeout: 5,
            maxRetries: 3,
            retryDelay: 0.1
        )

        let (client, clock) = makeClient(using: server, configOverride: config)

        async let response = client.torrentGet(ids: nil, fields: nil)

        await clock.advance(by: .milliseconds(100))
        await clock.run()
        await clock.advance(by: .milliseconds(200))
        await clock.run()
        await clock.advance(by: .milliseconds(400))
        await clock.run()

        _ = try await response

        try server.assertAllScenariosFinished()
    }

    // MARK: - Helpers

    private func makeClient(
        using server: TransmissionMockServer,
        configOverride: TransmissionClientConfig? = nil
    ) -> (client: TransmissionClient, clock: TestClock<Duration>) {
        let sessionConfiguration: URLSessionConfiguration =
            server.makeEphemeralSessionConfiguration()

        let config: TransmissionClientConfig =
            configOverride
            ?? TransmissionClientConfig(
                baseURL: baseURL,
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
