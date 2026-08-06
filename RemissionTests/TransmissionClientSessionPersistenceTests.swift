import Clocks
import Foundation
import Testing

@testable import Remission

// MARK: - Session ID Persistence Tests

@Suite("Session ID Persistence")
struct SessionIDPersistenceTests {

    @Test("Session ID from 409 is reused in subsequent requests without new 409")
    func sessionIDFrom409IsReused() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()
        let expectedSessionID = "persistent-session-id-abc"
        let url = URL(string: "http://localhost:9091/transmission/rpc")!

        // 1. First request → 409 (triggers handshake, stores session ID)
        MockURLProtocol.enqueue { _ in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": expectedSessionID]
            )!
            return (response, Data())
        }

        // 2. Retry of first request → 200 (sends session ID in header)
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == expectedSessionID, "Retry should send session ID from 409")

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        // 3. Second request → 200 (reuses session ID without new 409)
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == expectedSessionID, "Session ID should be reused from 409 response")

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient(clock: clock)
        _ = try await client.sessionGet()
        _ = try await client.sessionGet()
    }

    @Test("Auth header is included in requests when credentials are configured")
    func authHeaderIsIncludedWhenCredentialsConfigured() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader != nil, "Authorization header should be present")
            #expect(authHeader?.hasPrefix("Basic ") == true, "Should use Basic auth")

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClientWithCredentials()
        _ = try await client.sessionGet()
    }

    @Test("No auth header when credentials are not configured")
    func noAuthHeaderWithoutCredentials() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(
                authHeader == nil,
                "Authorization header should NOT be present without credentials"
            )

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient()
        _ = try await client.sessionGet()
    }

    @Test("Session ID is NOT sent on first request before 409")
    func sessionIDNotSentOnFirstRequest() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { request in
            let sessionIDHeader = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(sessionIDHeader == nil, "Session ID should not be sent before 409 response")

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient()
        _ = try await client.sessionGet()
    }

    @Test("Multiple 409 responses update session ID each time")
    func multiple409ResponsesUpdateSessionID() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()

        // 1. First 409 → session ID "v1"
        MockURLProtocol.enqueue { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:9091/transmission/rpc")!,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": "session-v1"]
            )!
            return (response, Data())
        }

        // 2. Second 409 → session ID "v2"
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == "session-v1", "Should send previous session ID on retry")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": "session-v2"]
            )!
            return (response, Data())
        }

        // 3. Success with latest session ID
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == "session-v2", "Should use latest session ID")

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient(clock: clock)
        _ = try await client.sessionGet()
    }
}

// MARK: - SessionStore Actor Isolation Tests

@Suite("SessionStore Actor Isolation")
struct SessionStoreIsolationTests {

    @Test("SessionStore stores and loads value correctly")
    func sessionStoreStoreAndLoad() async {
        let store = SessionStore()
        #expect(await store.load() == nil, "Initial state should be nil")

        await store.store("test-session-123")
        #expect(await store.load() == "test-session-123")

        await store.store(nil)
        #expect(await store.load() == nil)
    }

    @Test("RPCModeStore stores and loads mode correctly")
    func rpcModeStoreStoreAndLoad() async {
        let store = RPCModeStore()
        #expect(await store.load() == nil)

        await store.store(.jsonRpc2)
        #expect(await store.load() == .jsonRpc2)

        await store.store(.legacy)
        #expect(await store.load() == .legacy)
    }

    @Test("JSONRPCIDStore generates sequential IDs")
    func jsonrpcIDStoreGeneratesSequentialIDs() async {
        let store = JSONRPCIDStore()
        let id1 = await store.next()
        let id2 = await store.next()
        let id3 = await store.next()

        if case .int(let v1) = id1, case .int(let v2) = id2, case .int(let v3) = id3 {
            #expect(v1 == 1)
            #expect(v2 == 2)
            #expect(v3 == 3)
        } else {
            Issue.record("Expected integer tags")
        }
    }
}

// MARK: - Helpers

private func makeClient(
    clock: any Clock<Duration> = ContinuousClock(),
    maxRetries: Int = 3,
    retryDelay: Double = 0.1,
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

private func makeClientWithCredentials(
    clock: any Clock<Duration> = ContinuousClock(),
    maxRetries: Int = 3,
    retryDelay: Double = 0.1
) -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(
        baseURL: url,
        username: "testuser",
        password: "testpassword",
        maxRetries: maxRetries,
        retryDelay: retryDelay
    )
    config.enableLogging = false
    config.rpcMode = .legacy

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: clock
    )
}
