import Foundation
import Testing

@testable import Remission

// MARK: - JSON-RPC 2.0 Fallback Tests

@Suite("JSON-RPC 2.0 Fallback to Legacy")
struct TransmissionClientJSONRPCFallbackTests {

    // MARK: - Auto mode ordering

    @Test("Auto mode sends JSON-RPC 2.0 request first")
    func autoModeSendsJsonRpc2First() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["version": .string("4.1.0"), "rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .auto)
        _ = try await client.sessionGet()

        let payloads = inspector.values
        #expect(payloads.count == 1)
        let json = try #require(
            try JSONSerialization.jsonObject(with: payloads[0]) as? [String: Any])
        #expect(json["jsonrpc"] as? String == "2.0", "Auto mode should send JSON-RPC 2.0 first")
        #expect(json["method"] as? String == "session_get")
    }

    // MARK: - Fallback reason detection

    @Test("Missing result in JSON-RPC response triggers fallback reason")
    func missingResultTriggersFallbackReason() async throws {
        MockURLProtocol.reset()

        let client = makeClient(mode: .jsonRpc2)

        MockURLProtocol.enqueue { _ in
            let raw = """
                {"jsonrpc":"2.0","id":1}
                """
            return (
                httpResponse(
                    url: URL(string: "http://localhost:9091/transmission/rpc")!,
                    statusCode: 200),
                Data(raw.utf8)
            )
        }

        await #expect(throws: RetryDecision.self) {
            _ = try await client.sessionGet()
        }
    }

    @Test("Unsupported jsonrpc version triggers fallback reason")
    func unsupportedVersionTriggersFallbackReason() async {
        MockURLProtocol.reset()

        let client = makeClient(mode: .jsonRpc2)

        MockURLProtocol.enqueue { _ in
            let raw = """
                {"jsonrpc":"1.0","result":{},"id":1}
                """
            return (
                httpResponse(
                    url: URL(string: "http://localhost:9091/transmission/rpc")!,
                    statusCode: 200),
                Data(raw.utf8)
            )
        }

        await #expect(throws: RetryDecision.self) {
            _ = try await client.sessionGet()
        }
    }

    // MARK: - Explicit JSON-RPC 2.0 mode behavior

    @Test("Explicit JSON-RPC 2.0 mode sends JSON-RPC envelope")
    func explicitJsonRpc2SendsCorrectEnvelope() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["version": .string("4.1.0"), "rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.sessionGet()

        let payloads = inspector.values
        #expect(payloads.count == 1)
        let json = try #require(
            try JSONSerialization.jsonObject(with: payloads[0]) as? [String: Any])
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["method"] as? String == "session_get")
    }

    @Test("Explicit JSON-RPC 2.0 mode does not fallback on business error")
    func explicitJsonRpc2NoFallbackOnBusinessError() async throws {
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
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .jsonRpc2)
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

        #expect(inspector.values.count == 1, "Explicit mode should not retry with different mode")
    }

    // MARK: - Mode persistence

    @Test("Auto mode persists resolved JSON-RPC 2.0 mode after successful request")
    func autoModePersistsJsonRpc2Mode() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["version": .string("4.1.0"), "rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .auto)
        _ = try await client.sessionGet()

        let persistedMode = await client.test_rpcResolver.rpcModeStoreConcrete?.load()
        #expect(
            persistedMode == .jsonRpc2,
            "Auto mode should persist JSON-RPC 2.0 after successful request")
    }

    @Test("Explicit JSON-RPC 2.0 mode does not persist to rpcModeStore (only auto does)")
    func explicitJsonRpc2DoesNotPersist() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["version": .string("4.1.0"), "rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.sessionGet()

        let persistedMode = await client.test_rpcResolver.rpcModeStoreConcrete?.load()
        #expect(
            persistedMode == nil,
            "Explicit mode should not persist to rpcModeStore — only auto mode does")
    }

    // MARK: - Auto mode fallback flow (demonstrates fixed behavior)

    @Test("Auto mode: JSON-RPC 2.0 failure falls back to legacy")
    func autoModeJsonRpc2FailureFallsBackToLegacy() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let raw = """
                {"jsonrpc":"2.0","id":1}
                """
            return (
                httpResponse(for: request, statusCode: 200),
                Data(raw.utf8)
            )
        }

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = TransmissionResponse(
                result: "success",
                arguments: .object(["rpc-version": .int(19)])
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .auto)
        _ = try await client.sessionGet()

        let payloads = inspector.values
        #expect(payloads.count == 2, "Should send JSON-RPC 2.0 first, then fallback to legacy")

        let first = try #require(
            try JSONSerialization.jsonObject(with: payloads[0]) as? [String: Any])
        #expect(first["jsonrpc"] as? String == "2.0", "First request should be JSON-RPC 2.0")

        let second = try #require(
            try JSONSerialization.jsonObject(with: payloads[1]) as? [String: Any])
        #expect(second["jsonrpc"] == nil, "Fallback request should be legacy envelope")
        #expect(second["method"] as? String == "session-get")
    }

    // MARK: - Session ID interaction with mode

    @Test("Session ID from 409 is preserved across mode attempts in auto mode")
    func sessionIDPreservedAcrossModeAttempts() async throws {
        MockURLProtocol.reset()
        let expectedSessionID = "fallback-session-abc"

        // First request (JSON-RPC 2.0) -> gets 409
        MockURLProtocol.enqueue { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:9091/transmission/rpc")!,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": expectedSessionID]
            )!
            return (response, Data())
        }

        // Retry with session ID (JSON-RPC 2.0) -> needs JSON-RPC 2.0 response format
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == expectedSessionID, "Session ID should be sent after 409 handshake")

            // Return JSON-RPC 2.0 format since we're still in JSON-RPC 2.0 mode
            let response = JSONRPCResponse(
                jsonrpc: "2.0",
                result: .object(["rpc_version": .int(19)]),
                error: nil,
                id: .int(1)
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .auto)
        _ = try await client.sessionGet()

        let storedSessionID = await client.test_auth.sessionStore.load()
        #expect(storedSessionID == expectedSessionID)
    }

    // MARK: - JSON-RPC 2.0 request body structure

    @Test("JSON-RPC 2.0 request uses snake_case method and params")
    func jsonRpc2RequestBodyStructure() async throws {
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
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .jsonRpc2)
        _ = try await client.sessionGet()

        let json = try #require(
            try JSONSerialization.jsonObject(with: inspector.values[0]) as? [String: Any])
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["method"] as? String == "session_get")
        #expect(json["params"] is [String: Any])
        #expect(json["id"] is Int)
    }

    @Test("Legacy request uses Transmission RPC envelope")
    func legacyRequestBodyStructure() async throws {
        MockURLProtocol.reset()
        let inspector = RequestBodyInspector()

        MockURLProtocol.enqueue { request in
            inspector.append(requestBodyData(from: request))
            let response = TransmissionResponse(
                result: "success",
                arguments: .object([:])
            )
            return (
                httpResponse(for: request, statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        let client = makeClient(mode: .legacy)
        _ = try await client.sessionGet()

        let json = try #require(
            try JSONSerialization.jsonObject(with: inspector.values[0]) as? [String: Any])
        #expect(json["jsonrpc"] == nil, "Legacy envelope should not contain jsonrpc field")
        #expect(json["method"] as? String == "session-get")
    }
}

// MARK: - Fallback Reason Detection Tests

@Suite("Fallback Reason Detection")
struct FallbackReasonDetectionTests {

    @Test("Missing result in JSON-RPC response is detected as fallback reason")
    func missingResultDetected() async throws {
        MockURLProtocol.reset()

        let client = makeClient(mode: .jsonRpc2)

        MockURLProtocol.enqueue { _ in
            let raw = """
                {"jsonrpc":"2.0","id":1}
                """
            return (
                httpResponse(
                    url: URL(string: "http://localhost:9091/transmission/rpc")!,
                    statusCode: 200),
                Data(raw.utf8)
            )
        }

        await #expect(throws: RetryDecision.self) {
            _ = try await client.sessionGet()
        }
    }

    @Test("Invalid JSON-RPC response shape is detected as fallback reason")
    func invalidShapeDetected() async throws {
        MockURLProtocol.reset()

        let client = makeClient(mode: .jsonRpc2)

        MockURLProtocol.enqueue { _ in
            let raw = """
                {"not_jsonrpc": true}
                """
            return (
                httpResponse(
                    url: URL(string: "http://localhost:9091/transmission/rpc")!,
                    statusCode: 200),
                Data(raw.utf8)
            )
        }

        await #expect(throws: RetryDecision.self) {
            _ = try await client.sessionGet()
        }
    }

    @Test("JSON-RPC business error does NOT trigger fallback reason")
    func businessErrorNotFallback() async throws {
        MockURLProtocol.reset()

        let client = makeClient(mode: .jsonRpc2)

        MockURLProtocol.enqueue { _ in
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
            return (
                httpResponse(
                    url: URL(string: "http://localhost:9091/transmission/rpc")!,
                    statusCode: 200),
                try JSONEncoder().encode(response)
            )
        }

        do {
            _ = try await client.sessionGet()
            Issue.record("Expected error")
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
    }
}

// MARK: - Helpers

private func makeClient(
    clock: any Clock<Duration> = ContinuousClock(),
    maxRetries: Int = 0,
    retryDelay: Double = 0,
    mode: TransmissionRPCMode = .legacy
) -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(
        baseURL: url,
        maxRetries: maxRetries,
        retryDelay: retryDelay
    )
    config.enableLogging = false
    config.rpcMode = mode

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: clock
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

private func httpResponse(
    url: URL,
    statusCode: Int,
    headers: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
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
