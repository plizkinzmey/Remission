import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient System & Session")
struct TransmissionClientSystemSessionTests {
    @Test("sessionGet отправляет session-get без аргументов")
    func sessionGetSendsExpectedMethod() async throws {
        // Проверяем базовый контракт: метод должен быть именно session-get и без arguments.
        MockURLProtocol.reset()
        let requests = RequestBox()
        let expected = makeSuccessResponse(arguments: ["rpc-version": .int(17)])

        MockURLProtocol.enqueue { request in
            let rpcRequest = try decodeRequest(from: request)
            requests.append(rpcRequest)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeClient()
        let response = try await client.sessionGet()

        #expect(response.result == "success")
        let recorded = requests.requests
        #expect(recorded.count == 1)
        #expect(recorded.first?.method == TransmissionClient.RPCMethod.sessionGet.rawValue)
        #expect(recorded.first?.arguments == nil)
    }

    @Test("freeSpace отправляет path в аргументах метода free-space")
    func freeSpaceSendsPathArgument() async throws {
        // Здесь важно зафиксировать форму arguments: {"path": "..."}.
        MockURLProtocol.reset()
        let expectedPath = "/volume/downloads"
        let expected = makeSuccessResponse(arguments: ["size-bytes": .int(1024)])

        MockURLProtocol.enqueue { request in
            let rpcRequest = try decodeRequest(from: request)
            #expect(rpcRequest.method == TransmissionClient.RPCMethod.freeSpace.rawValue)

            guard case .object(let arguments)? = rpcRequest.arguments,
                case .string(let path)? = arguments["path"]
            else {
                Issue.record("Ожидали arguments.path как строку")
                return (httpResponse(for: request, statusCode: 200), try encode(expected))
            }

            #expect(path == expectedPath)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeClient()
        _ = try await client.freeSpace(path: expectedPath)
    }

    @Test("performHandshake обрабатывает 409, сохраняет session-id и повторяет запрос")
    func performHandshakeHandlesSessionConflictAndStoresSessionID() async throws {
        // Этот тест покрывает ключевой сценарий рукопожатия Transmission: 409 -> session-id -> retry.
        MockURLProtocol.reset()
        let sessionID = "session-abc"
        let headers = SessionHeaderBox()
        let handshakeResponse = makeSuccessResponse(
            arguments: [
                "rpc-version": .int(20),
                "version": .string("4.0.3")
            ]
        )

        MockURLProtocol.enqueue { request in
            headers.append(request.value(forHTTPHeaderField: "X-Transmission-Session-Id"))
            let response = httpResponse(
                for: request,
                statusCode: 409,
                headers: ["X-Transmission-Session-Id": sessionID]
            )
            return (response, Data())
        }

        MockURLProtocol.enqueue { request in
            headers.append(request.value(forHTTPHeaderField: "X-Transmission-Session-Id"))
            return (httpResponse(for: request, statusCode: 200), try encode(handshakeResponse))
        }

        let client = makeClient()
        let handshake = try await client.performHandshake()

        #expect(handshake.sessionID == sessionID)
        #expect(handshake.rpcVersion == 20)
        #expect(handshake.isCompatible == true)

        let recordedHeaders = headers.values
        #expect(recordedHeaders.count == 2)
        #expect(recordedHeaders.last == sessionID)
    }

    @Test("performHandshake бросает versionUnsupported при rpc-version ниже минимума")
    func performHandshakeFailsOnUnsupportedVersion() async {
        // Фиксируем ветку несовместимой версии, чтобы UI мог показывать корректную ошибку.
        MockURLProtocol.reset()
        let response = makeSuccessResponse(
            arguments: [
                "rpc-version": .int(13),
                "version": .string("2.94")
            ]
        )

        MockURLProtocol.enqueue { request in
            (httpResponse(for: request, statusCode: 200), try encode(response))
        }

        let client = makeClient()

        do {
            _ = try await client.performHandshake()
            Issue.record("Ожидали APIError.versionUnsupported, но ошибка не была брошена")
        } catch let error as APIError {
            #expect(error == .versionUnsupported(version: "2.94"))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }

    @Test("performHandshake бросает decodingFailed при отсутствии rpc-version")
    func performHandshakeFailsWhenRPCVersionMissing() async {
        // Эта проверка защищает от частично валидных ответов, где отсутствует rpc-version.
        MockURLProtocol.reset()
        let response = makeSuccessResponse(arguments: ["version": .string("4.0.3")])

        MockURLProtocol.enqueue { request in
            (httpResponse(for: request, statusCode: 200), try encode(response))
        }

        let client = makeClient()

        do {
            _ = try await client.performHandshake()
            Issue.record("Ожидали APIError.decodingFailed, но ошибка не была брошена")
        } catch let error as APIError {
            switch error {
            case .decodingFailed:
                break
            default:
                Issue.record("Ожидали decodingFailed, получили: \(error)")
            }
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }

    @Test("sessionSet отправляет arguments")
    func sessionSetSendsArguments() async throws {
        MockURLProtocol.reset()
        let requests = RequestBox()
        let expected = makeSuccessResponse(arguments: [:])

        MockURLProtocol.enqueue { request in
            let rpcRequest = try decodeRequest(from: request)
            requests.append(rpcRequest)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeClient()
        let arguments: AnyCodable = .object(["download-dir": .string("/tmp")])
        let response = try await client.sessionSet(arguments: arguments)

        #expect(response.result == "success")
        let recorded = requests.requests
        #expect(recorded.count == 1)
        #expect(recorded.first?.method == TransmissionClient.RPCMethod.sessionSet.rawValue)
        #expect(recorded.first?.arguments == arguments)
    }

    @Test("sessionStats отправляет session-stats без аргументов")
    func sessionStatsSendsExpectedMethod() async throws {
        MockURLProtocol.reset()
        let requests = RequestBox()
        let expected = makeSuccessResponse(arguments: [:])

        MockURLProtocol.enqueue { request in
            let rpcRequest = try decodeRequest(from: request)
            requests.append(rpcRequest)
            return (httpResponse(for: request, statusCode: 200), try encode(expected))
        }

        let client = makeClient()
        let response = try await client.sessionStats()

        #expect(response.result == "success")
        let recorded = requests.requests
        #expect(recorded.count == 1)
        #expect(recorded.first?.method == TransmissionClient.RPCMethod.sessionStats.rawValue)
        #expect(recorded.first?.arguments == nil)
    }
}

// MARK: - Test Helpers

private func makeClient() -> TransmissionClient {
    let url = URL(string: "http://localhost:9091/transmission/rpc")!
    var config = TransmissionClientConfig(baseURL: url, maxRetries: 0, retryDelay: 0)
    config.enableLogging = false

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MockURLProtocol.self]

    return TransmissionClient(
        config: config,
        sessionConfiguration: sessionConfiguration,
        clock: ContinuousClock()
    )
}

private func decodeRequest(from request: URLRequest) throws -> TransmissionRequest {
    let data = requestBodyData(from: request)
    do {
        return try JSONDecoder().decode(TransmissionRequest.self, from: data)
    } catch {
        Issue.record("Не удалось декодировать TransmissionRequest: \(error)")
        return TransmissionRequest(method: "<decode-failed>")
    }
}

private func makeSuccessResponse(arguments: [String: AnyCodable]) -> TransmissionResponse {
    TransmissionResponse(result: "success", arguments: .object(arguments))
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

private final class RequestBox: @unchecked Sendable {
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

private final class SessionHeaderBox: @unchecked Sendable {
    private var storage: [String?] = []
    private let lock = NSLock()

    var values: [String?] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: String?) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}
