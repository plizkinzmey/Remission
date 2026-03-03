import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient RPC Mode")
struct TransmissionClientRPCModeTests {
    @Test("jsonRpc2 mode sends JSON-RPC envelope and snake_case method")
    func jsonRpc2SendsJSONRPCRequest() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            let body = requestBodyData(from: request)
            inspector.append(body)
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["version": .string("4.1.1"), "rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.sessionGet()

        let payload = try #require(inspector.values.first)
        let json = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["method"] as? String == "session_get")
        #expect(json["params"] is [String: Any])
        #expect(json["id"] is Int)
    }

    @Test("auto mode falls back to legacy and caches resolved mode")
    func autoModeFallsBackAndCachesLegacy() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            // Incompatible JSON-RPC shape: no result/error envelope fields.
            return (httpResponse(for: request, statusCode: 200), Data("{}".utf8))
        }

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let success = TransmissionResponse(
                result: "success",
                arguments: .object(["rpc-version": .int(19), "version": .string("4.1.1")])
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(success))
        }

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let success = TransmissionResponse(
                result: "success",
                arguments: .object(["rpc-version": .int(19), "version": .string("4.1.1")])
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(success))
        }

        let client = makeClient(mode: .auto)
        _ = try await client.sessionGet()
        _ = try await client.sessionGet()

        let payloads = inspector.values
        #expect(payloads.count == 3)
        guard payloads.count >= 3 else { return }

        let first = try #require(try JSONSerialization.jsonObject(with: payloads[0]) as? [String: Any])
        #expect(first["jsonrpc"] as? String == "2.0")
        #expect(first["method"] as? String == "session_get")

        let second = try #require(try JSONSerialization.jsonObject(with: payloads[1]) as? [String: Any])
        #expect(second["jsonrpc"] == nil)
        #expect(second["method"] as? String == "session-get")

        let third = try #require(try JSONSerialization.jsonObject(with: payloads[2]) as? [String: Any])
        #expect(third["jsonrpc"] == nil)
        #expect(third["method"] as? String == "session-get")
    }

    @Test("performHandshake on JSON-RPC returns mode and semver")
    func handshakeCapturesJSONRPCSemverAndMode() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object([
                    "version": .string("4.1.1"),
                    "rpc_version": .int(19),
                    "rpc_version_semver": .string("6.0.1")
                ]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        let handshake = try await client.performHandshake()
        #expect(handshake.rpcMode == .jsonRpc2)
        #expect(handshake.rpcVersionSemver == "6.0.1")
    }

    @Test("jsonRpc2 converts legacy argument keys to snake_case")
    func jsonRpc2ConvertsArgumentKeysToSnakeCase() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object([:]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.sessionSet(
            arguments: .object([
                "speed-limit-down-enabled": .bool(true),
                "seedRatioLimit": .double(1.5)
            ])
        )

        let payload = try #require(inspector.values.first)
        let json = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let params = try #require(json["params"] as? [String: Any])
        #expect(params["speed_limit_down_enabled"] as? Bool == true)
        #expect(params["seed_ratio_limit"] as? Double == 1.5)
    }

    @Test("jsonRpc2 converts torrent_get fields entries to snake_case")
    func jsonRpc2ConvertsTorrentGetFieldNamesToSnakeCase() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["torrents": .array([])]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.torrentGet(
            ids: [1],
            fields: ["percentDone", "rateDownload", "uploadRatio", "peersConnected"]
        )

        let payload = try #require(inspector.values.first)
        let json = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let params = try #require(json["params"] as? [String: Any])
        let fields = try #require(params["fields"] as? [String])
        #expect(fields.contains("percent_done"))
        #expect(fields.contains("rate_download"))
        #expect(fields.contains("upload_ratio"))
        #expect(fields.contains("peers_connected"))
    }

    @Test("jsonRpc2 sends session_stats and decodes snake_case payload")
    func jsonRpc2SessionStatsUsesSnakeCaseMethod() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object([
                    "active_torrent_count": .int(4),
                    "download_speed": .int(1024)
                ]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        let response = try await client.sessionStats()

        let payload = try #require(inspector.values.first)
        let json = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(json["method"] as? String == "session_stats")
        #expect(json["params"] is [String: Any])

        guard case .object(let arguments)? = response.arguments else {
            Issue.record("Expected object arguments in sessionStats response")
            return
        }
        #expect(arguments["active_torrent_count"]?.intValue == 4)
    }

    @Test("jsonRpc2 sends free_space path and decodes size_bytes")
    func jsonRpc2FreeSpaceUsesSnakeCaseMethodAndParams() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()
        let expectedPath = "/downloads"

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["size_bytes": .int(123_456)]),
                error: nil,
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        let response = try await client.freeSpace(path: expectedPath)

        let payload = try #require(inspector.values.first)
        let json = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(json["method"] as? String == "free_space")
        let params = try #require(json["params"] as? [String: Any])
        #expect(params["path"] as? String == expectedPath)

        let mapper = TransmissionDomainMapper()
        #expect(try mapper.mapFreeSpaceBytes(from: response) == 123_456)
    }

    @Test("jsonRpc2 maps error.data.error_string into APIError")
    func jsonRpc2ErrorStringIsMapped() async {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: nil,
                error: JSONRPCError(
                    code: 7,
                    message: "HTTP error from backend service",
                    data: .object(["error_string": .string("Couldn't test port: No Response (0)")])
                ),
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .jsonRpc2)
        do {
            _ = try await client.sessionGet()
            Issue.record("Expected APIError")
        } catch let error as APIError {
            if case .jsonRPC(let code, let message, let errorString) = error {
                #expect(code == 7)
                #expect(message == "HTTP error from backend service")
                #expect(errorString?.contains("Couldn't test port") == true)
            } else {
                Issue.record("Expected APIError.jsonRPC(...), got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("auto mode does not fallback on valid JSON-RPC business error")
    func autoModeDoesNotFallbackOnJSONRPCBusinessError() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: nil,
                error: JSONRPCError(
                    code: 7,
                    message: "HTTP error from backend service",
                    data: .object(["error_string": .string("Access denied")])
                ),
                id: .int(1)
            )
            return (httpResponse(for: request, statusCode: 200), try JSONEncoder().encode(response))
        }

        let client = makeClient(mode: .auto)
        do {
            _ = try await client.sessionGet()
            Issue.record("Expected APIError.jsonRPC")
        } catch let error as APIError {
            if case .jsonRPC(let code, _, let errorString) = error {
                #expect(code == 7)
                #expect(errorString == "Access denied")
            } else {
                Issue.record("Expected .jsonRPC, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Must stay on JSON-RPC path: only one request should be sent.
        #expect(inspector.values.count == 1)
        let first = try #require(
            try JSONSerialization.jsonObject(with: inspector.values[0]) as? [String: Any]
        )
        #expect(first["jsonrpc"] as? String == "2.0")
    }

    @Test("jsonRpc2 rejects response with unsupported jsonrpc version")
    func jsonRpc2RejectsUnsupportedVersion() async {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let raw = """
            {"jsonrpc":"1.0","result":{"rpc_version":19},"id":1}
            """
            return (httpResponse(for: request, statusCode: 200), Data(raw.utf8))
        }

        let client = makeClient(mode: .jsonRpc2)
        await #expect(throws: APIError.self) {
            _ = try await client.sessionGet()
        }
    }
}

private func makeClient(mode: TransmissionRPCMode) -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(baseURL: url, maxRetries: 0, retryDelay: 0)
    config.enableLogging = false
    config.rpcMode = mode

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: ContinuousClock()
    )
}

private func requestBodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }

    if let stream = request.httpBodyStream {
        return readAll(from: stream)
    }

    Issue.record("URLRequest does not contain httpBody or httpBodyStream")
    return Data()
}

private func httpResponse(
    for request: URLRequest,
    statusCode: Int,
    headers: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headers
    )!
}

private final class RequestBodyInspector: @unchecked Sendable {
    private var storage: [Data] = []
    private let lock = NSLock()

    var values: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: Data) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private func readAll(from stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }

    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var result = Data()

    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead > 0 {
            result.append(buffer, count: bytesRead)
        } else {
            break
        }
    }

    return result
}
