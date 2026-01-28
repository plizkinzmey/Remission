import Foundation

/// A reusable URLProtocol mock for testing network requests.
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    public typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) private static var handlers: [Handler] = []
    private static let lock = NSLock()

    /// Enqueues a handler to respond to the next request.
    public static func enqueue(_ handler: @escaping Handler) {
        lock.lock()
        handlers.append(handler)
        lock.unlock()
    }

    /// Resets the queue of handlers.
    public static func reset() {
        lock.lock()
        handlers.removeAll()
        lock.unlock()
    }

    private static func dequeue() -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        guard handlers.isEmpty == false else { return nil }
        return handlers.removeFirst()
    }

    // MARK: - URLProtocol

    public override static func canInit(with request: URLRequest) -> Bool { true }
    public override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        guard let handler = Self.dequeue() else {
            // Fail if no handler is enqueued instead of crashing, to avoid taking down the test suite
            let error = NSError(
                domain: "MockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "MockURLProtocol handler queue is empty"]
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    public override func stopLoading() {}
}
