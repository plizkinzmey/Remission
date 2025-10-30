import Clocks
import Foundation
import Testing

@testable import Remission

func makeTransmissionClient(
    baseURL: URL,
    config: TransmissionClientConfig? = nil
) -> (client: TransmissionClient, clock: TestClock<Duration>) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    configuration.timeoutIntervalForRequest = 5
    let effectiveConfig = config ?? TransmissionClientConfig(baseURL: baseURL)
    let testClock = TestClock<Duration>()
    let trustStore = TransmissionTrustStore.inMemory()
    let client = TransmissionClient(
        config: effectiveConfig,
        sessionConfiguration: configuration,
        trustStore: trustStore,
        trustDecisionHandler: { _ in .trustPermanently },
        clock: testClock
    )
    return (client, testClock)
}

func runTransmissionSuccessTest(
    baseURL: URL,
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

    let (client, _) = makeTransmissionClient(baseURL: baseURL)
    let response = try await call(client)
    #expect(response == expectedResponse)

    let urlRequest = try #require(MockURLProtocol.requests.last)
    let requestModel = try decodeTransmissionRequest(from: urlRequest)
    try validate(requestModel)
}

func runTransmissionErrorTest(
    baseURL: URL,
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

    let (client, _) = makeTransmissionClient(baseURL: baseURL)

    do {
        _ = try await call(client)
        #expect(Bool(false), "Ожидалась APIError, но метод завершился успешно")
    } catch let error as APIError {
        let urlRequest = try #require(MockURLProtocol.requests.last)
        let requestModel = try decodeTransmissionRequest(from: urlRequest)
        try validate(requestModel)
        assertError(error)
    } catch {
        #expect(Bool(false), "Ожидалась APIError, получено \(error)")
    }
}

func decodeTransmissionRequest(from request: URLRequest) throws -> TransmissionRequest {
    let data = try #require(request.httpBody, "У запроса отсутствует тело")
    return try JSONDecoder().decode(TransmissionRequest.self, from: data)
}

class MockURLProtocol: URLProtocol {
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
