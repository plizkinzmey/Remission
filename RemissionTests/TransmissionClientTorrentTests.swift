import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient Torrent RPC")
struct TransmissionClientTorrentTests {
    @Test("torrentGet без параметров отправляет torrent-get без arguments")
    func torrentGetWithoutArguments() async throws {
        // Фиксируем контракт: при отсутствии ids/fields arguments должны быть nil.
        MockTorrentURLProtocol.reset()
        let requests = TorrentRequestBox()
        let expected = TransmissionResponse(result: "success", arguments: .object([:]))

        MockTorrentURLProtocol.enqueue { request in
            let rpcRequest = decodeRequest(from: request)
            requests.append(rpcRequest)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeTorrentClient()
        _ = try await client.torrentGet()

        let recorded = requests.requests
        #expect(recorded.count == 1)
        #expect(recorded.first?.method == TransmissionClient.RPCMethod.torrentGet.rawValue)
        #expect(recorded.first?.arguments == nil)
    }

    @Test("torrentGet с ids и fields кодирует оба массива в arguments")
    func torrentGetWithIDsAndFields() async throws {
        // Проверяем форму arguments: ids -> [int], fields -> [string].
        MockTorrentURLProtocol.reset()
        let expected = TransmissionResponse(result: "success", arguments: .object([:]))

        MockTorrentURLProtocol.enqueue { request in
            let rpcRequest = decodeRequest(from: request)
            #expect(rpcRequest.method == TransmissionClient.RPCMethod.torrentGet.rawValue)

            guard case .object(let arguments)? = rpcRequest.arguments else {
                Issue.record("Ожидали arguments как object")
                return (httpResponse(for: request, statusCode: 200), try encode(expected))
            }

            #expect(arguments["ids"] == .array([.int(1), .int(2)]))
            #expect(arguments["fields"] == .array([.string("id"), .string("name")]))
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeTorrentClient()
        _ = try await client.torrentGet(ids: [1, 2], fields: ["id", "name"])
    }

    @Test("torrentAdd кодирует metainfo в base64 и пробрасывает опциональные поля")
    func torrentAddEncodesMetainfoAndOptions() async throws {
        // Это важный контракт для torrent-add: metainfo должен быть base64 строкой.
        MockTorrentURLProtocol.reset()
        let expected = TransmissionResponse(result: "success", arguments: .object([:]))
        let metainfo = Data([0x01, 0x02, 0x03])
        let base64 = metainfo.base64EncodedString()

        MockTorrentURLProtocol.enqueue { request in
            let rpcRequest = decodeRequest(from: request)
            #expect(rpcRequest.method == TransmissionClient.RPCMethod.torrentAdd.rawValue)

            guard case .object(let arguments)? = rpcRequest.arguments else {
                Issue.record("Ожидали arguments как object")
                return (httpResponse(for: request, statusCode: 200), try encode(expected))
            }

            #expect(arguments["filename"] == .string("magnet:?xt=urn:btih:123"))
            #expect(arguments["metainfo"] == .string(base64))
            #expect(arguments["download-dir"] == .string("/downloads"))
            #expect(arguments["paused"] == .bool(true))
            #expect(arguments["labels"] == .array([.string("linux"), .string("iso")]))

            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeTorrentClient()
        _ = try await client.torrentAdd(
            filename: "magnet:?xt=urn:btih:123",
            metainfo: metainfo,
            downloadDir: "/downloads",
            paused: true,
            labels: ["linux", "iso"]
        )
    }

    @Test("torrentRemove добавляет delete-local-data только когда он передан")
    func torrentRemoveRespectsDeleteLocalDataFlag() async throws {
        // Проверяем опциональный флаг delete-local-data.
        MockTorrentURLProtocol.reset()
        let expected = TransmissionResponse(result: "success", arguments: .object([:]))

        MockTorrentURLProtocol.enqueue { request in
            let rpcRequest = decodeRequest(from: request)
            guard case .object(let arguments)? = rpcRequest.arguments else {
                Issue.record("Ожидали arguments как object")
                return (httpResponse(for: request, statusCode: 200), try encode(expected))
            }

            #expect(arguments["ids"] == .array([.int(7)]))
            #expect(arguments["delete-local-data"] == .bool(true))
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeTorrentClient()
        _ = try await client.torrentRemove(ids: [7], deleteLocalData: true)
    }

    @Test("torrentSet всегда добавляет ids даже если arguments не object")
    func torrentSetAlwaysInjectsIDs() async throws {
        // Контракт для torrent-set: ids должны присутствовать в любом случае.
        MockTorrentURLProtocol.reset()
        let expected = TransmissionResponse(result: "success", arguments: .object([:]))

        MockTorrentURLProtocol.enqueue { request in
            let rpcRequest = decodeRequest(from: request)
            #expect(rpcRequest.method == TransmissionClient.RPCMethod.torrentSet.rawValue)

            guard case .object(let arguments)? = rpcRequest.arguments else {
                Issue.record("Ожидали arguments как object")
                return (httpResponse(for: request, statusCode: 200), try encode(expected))
            }

            #expect(arguments["ids"] == .array([.int(1), .int(2)]))
            #expect(arguments["downloadLimited"] == nil)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeTorrentClient()
        _ = try await client.torrentSet(ids: [1, 2], arguments: .string("not-an-object"))
    }
}

// MARK: - Helpers

private func makeTorrentClient() -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(baseURL: url, maxRetries: 0, retryDelay: 0)
    config.enableLogging = false

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockTorrentURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: ContinuousClock()
    )
}

private func decodeRequest(from request: URLRequest) -> TransmissionRequest {
    let data = requestBodyData(from: request)
    do {
        return try JSONDecoder().decode(TransmissionRequest.self, from: data)
    } catch {
        Issue.record("Не удалось декодировать TransmissionRequest: \(error)")
        return TransmissionRequest(method: "<decode-failed>")
    }
}

private func encode(_ response: TransmissionResponse) throws -> Data {
    try JSONEncoder().encode(response)
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

private func requestBodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }

    if let stream = request.httpBodyStream {
        return readAll(from: stream)
    }

    Issue.record("URLRequest не содержит httpBody или httpBodyStream")
    return Data()
}

private func readAll(from stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 4 * 1_024
    var buffer = Array(repeating: UInt8(0), count: bufferSize)

    while stream.hasBytesAvailable {
        let readCount = stream.read(&buffer, maxLength: bufferSize)
        if readCount < 0 {
            Issue.record(
                "Ошибка чтения httpBodyStream: \(stream.streamError?.localizedDescription ?? "unknown")"
            )
            break
        }
        if readCount == 0 {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}

private final class TorrentRequestBox: @unchecked Sendable {
    private var storage: [TransmissionRequest] = []
    private let lock = NSLock()

    var requests: [TransmissionRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ request: TransmissionRequest) {
        lock.lock()
        storage.append(request)
        lock.unlock()
    }
}

private final class MockTorrentURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) private static var handlers: [Handler] = []
    private static let lock = NSLock()

    static func enqueue(_ handler: @escaping Handler) {
        lock.lock()
        handlers.append(handler)
        lock.unlock()
    }

    static func reset() {
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

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.dequeue() else {
            fatalError("MockTorrentURLProtocol handler queue is empty")
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

    override func stopLoading() {}
}
