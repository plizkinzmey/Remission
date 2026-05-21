import Clocks
import Foundation
import XCTest

@testable import Remission

final class TransmissionClientRetryTests: XCTestCase {
    func testNoRetryOnBadURL() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { _ in
            throw URLError(.badURL)
        }

        MockURLProtocol.enqueue { request in
            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient()

        do {
            _ = try await client.sessionGet()
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            switch error {
            case .unknown(let details):
                XCTAssertTrue(details.contains("URL error"))
            default:
                XCTFail("Unexpected APIError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }

    func testRetryOnNetworkTimeout() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { request in
            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient(maxRetries: 2, retryDelay: 0)
        let response = try await client.sessionGet()

        XCTAssertEqual(response.result, "success")
    }

    func testExceedMaxRetries() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }
        MockURLProtocol.enqueue { _ in throw URLError(.timedOut) }

        let client = makeClient(maxRetries: 2, retryDelay: 0)

        do {
            _ = try await client.sessionGet()
            XCTFail("Expected APIError.networkUnavailable")
        } catch let error as APIError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }

    func testSessionConflictRetry() async throws {
        MockURLProtocol.reset()
        let newSessionID = "new-session-id-123"
        let receivedSessionID = LockedValue<String?>(nil)

        MockURLProtocol.enqueue { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Transmission-Session-Id": newSessionID]
            )!
            return (response, Data())
        }

        MockURLProtocol.enqueue { request in
            receivedSessionID.set(request.value(forHTTPHeaderField: "X-Transmission-Session-Id"))

            let data = try JSONEncoder().encode(TransmissionResponse(result: "success"))
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data
            )
        }

        let client = makeClient()
        let response = try await client.sessionGet()

        XCTAssertEqual(response.result, "success")
        XCTAssertEqual(receivedSessionID.value, newSessionID)
    }

    func testSessionConflictLimit() async throws {
        MockURLProtocol.reset()
        let newSessionID = "session-id"

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

        let client = makeClient()

        do {
            _ = try await client.sessionGet()
            XCTFail("Expected APIError.sessionConflict")
        } catch let error as APIError {
            XCTAssertEqual(error, .sessionConflict)
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
}

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
    config.rpcMode = .legacy

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: clock
    )
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }
}
