import Clocks
import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient Retry & Error Logic")
struct TransmissionClientRetryTests {

    @Test("Rethrows URLError immediately if not retriable (e.g. badURL)")
    func testNoRetryOnBadURL() async throws {
        MockURLProtocol.reset()

        // Enqueue failure
        MockURLProtocol.enqueue { _ in
            throw URLError(.badURL)
        }

        // Enqueue success response (should NOT be called)
        MockURLProtocol.enqueue { request in
            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient()

        var capturedError: APIError?
        do {
            _ = try await client.sessionGet()
            Issue.record("Expected error to be thrown")
        } catch let error as APIError {
            capturedError = error
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }

        guard let error = capturedError else { return }

        // .badURL is mapped to .unknown(details: "URL error: ...") by APIError.mapURLError
        switch error {
        case .unknown(let details):
            #expect(details.contains("URL error"))
        default:
            Issue.record("Unexpected APIError case: \(error)")
        }
    }

    @Test("Retries on network timeout with backoff")
    func testRetryOnNetworkTimeout() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()

        // 1. Fail (attempt 0)
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }

        // 2. Fail (attempt 1)
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }

        // 3. Success
        MockURLProtocol.enqueue { request in
            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient(clock: clock, retryDelay: 0.1)

        let task = Task {
            try await client.sessionGet()
        }

        // Advance clock to trigger retries (0.1s + 0.2s = 0.3s total needed)
        await clock.advance(by: .milliseconds(500))

        let response = try await task.value
        #expect(response.result == "success")
    }

    @Test("Exceeding max retries throws networkUnavailable for timeout")
    func testExceedMaxRetries() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()

        // Max retries = 2. Total attempts allowed = 3.
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }

        let client = makeClient(clock: clock, maxRetries: 2, retryDelay: 0.1)

        let task = Task {
            try await client.sessionGet()
        }

        await clock.advance(by: .milliseconds(500))

        await #expect(throws: APIError.networkUnavailable) {
            try await task.value
        }
    }

    @Test("Session Conflict (409) updates session ID and retries immediately")
    func testSessionConflictRetry() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()
        let newSessionID = "new-session-id-123"

        // 1. 409 Conflict
        MockURLProtocol.enqueue { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": newSessionID]
            )!
            return (response, Data())
        }

        // 2. Success
        MockURLProtocol.enqueue { request in
            let header = request.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            #expect(header == newSessionID)

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient(clock: clock)
        let response = try await client.sessionGet()

        #expect(response.result == "success")
    }

    @Test("Session Conflict loop limit throws sessionConflict")
    func testSessionConflictLimit() async throws {
        MockURLProtocol.reset()
        let clock = TestClock()
        let newSessionID = "session-id"

        // Return 409 multiple times. Client should throw sessionConflict after limit.
        for _ in 0..<5 {
            MockURLProtocol.enqueue { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["X-Transmission-Session-Id": newSessionID]
                )!
                return (response, Data())
            }
        }

        let client = makeClient(clock: clock)

        await #expect(throws: APIError.sessionConflict) {
            try await client.sessionGet()
        }
    }
}

// MARK: - Helpers

private func makeClient(
    clock: any Clock<Duration> = ContinuousClock(),
    maxRetries: Int = 3,
    retryDelay: Double = 0.1
) -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(
        baseURL: url,
        username: "user",
        password: "password",
        maxRetries: maxRetries,
        retryDelay: retryDelay
    )
    config.enableLogging = false

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: clock
    )
}
