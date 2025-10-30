import Foundation

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
