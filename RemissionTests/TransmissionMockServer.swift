import Foundation
import Testing

@testable import Remission

// MARK: - Transmission Mock Server
// Референсы по реализации макета HTTP поверх URLProtocol:
// - URL Loading System: https://developer.apple.com/documentation/foundation/urlprotocol
// - Mockingjay (pattern for request matching + scripted responses): https://github.com/kylef/mockingjay/blob/master/README.md
// - Swift Testing async patterns: https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/testing-asynchronous-code.md

// MARK: - Errors

enum TransmissionMockError: Error, LocalizedError, CustomNSError, Sendable {
    case serverNotRegistered
    case unexpectedRequest(description: String)
    case decodingFailed(String)
    case assertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRegistered:
            return "TransmissionMockServer не зарегистрирован. "
                + "Вызовите makeEphemeralSessionConfiguration() перед использованием клиента."
        case .unexpectedRequest(let description):
            return "TransmissionMockServer получил неожиданный запрос: \(description)"
        case .decodingFailed(let details):
            return "TransmissionMockServer не смог декодировать TransmissionRequest: \(details)"
        case .assertionFailed(let description):
            return "TransmissionMockServer assertion не выполнен: \(description)"
        }
    }

    static var errorDomain: String { "RemissionTests.TransmissionMockError" }

    var errorCode: Int {
        switch self {
        case .serverNotRegistered: return 0
        case .unexpectedRequest: return 1
        case .decodingFailed: return 2
        case .assertionFailed: return 3
        }
    }

    var errorUserInfo: [String: Any] {
        if let description = errorDescription {
            return [NSLocalizedDescriptionKey: description]
        }
        return [:]
    }
}

// MARK: - Scenario Models

public struct TransmissionMockScenario: Sendable {
    public let name: String
    public let steps: [TransmissionMockStep]

    public init(name: String, steps: [TransmissionMockStep]) {
        self.name = name
        self.steps = steps
    }
}

public struct TransmissionMockStep: Sendable {
    public let matcher: TransmissionMockMatcher
    public let response: TransmissionMockResponsePlan
    public let assertions: [TransmissionMockAssertion]
    public let repeats: Int?

    public init(
        matcher: TransmissionMockMatcher,
        response: TransmissionMockResponsePlan,
        assertions: [TransmissionMockAssertion] = [],
        repeats: Int? = nil
    ) {
        self.matcher = matcher
        self.response = response
        self.assertions = assertions
        self.repeats = repeats
    }

    func copy(with response: TransmissionMockResponsePlan) -> TransmissionMockStep {
        TransmissionMockStep(
            matcher: matcher,
            response: response,
            assertions: assertions,
            repeats: nil
        )
    }
}

public struct TransmissionMockMatcher: Sendable {
    public let description: String
    public let matches: @Sendable (TransmissionRequest, URLRequest) -> Bool

    public init(
        description: String,
        matches: @escaping @Sendable (TransmissionRequest, URLRequest) -> Bool
    ) {
        self.description = description
        self.matches = matches
    }

    public static func method(_ name: String) -> Self {
        TransmissionMockMatcher(description: "method == \(name)") { request, _ in
            request.method == name
        }
    }

    public static func custom(
        description: String,
        _ predicate: @escaping @Sendable (TransmissionRequest) -> Bool
    ) -> Self {
        TransmissionMockMatcher(description: description) { request, _ in
            predicate(request)
        }
    }
}

extension TransmissionMockStep {
    /// Создает шаг, моделирующий HTTP 409 handshake с передачей session-id
    /// и автоматическим добавлением последующего ответа.
    public static func handshake(
        method: String = "session-get",
        sessionID: String,
        followUp: TransmissionMockResponsePlan,
        assertions: [TransmissionMockAssertion] = []
    ) -> Self {
        TransmissionMockStep(
            matcher: .method(method),
            response: .handshake(sessionID: sessionID, followUp: followUp),
            assertions: assertions
        )
    }

    /// Создает шаг с успешным Transmission RPC ответом.
    public static func rpcSuccess(
        method: String,
        arguments: AnyCodable? = nil,
        tag: TransmissionTag? = nil,
        repeats: Int? = nil,
        assertions: [TransmissionMockAssertion] = []
    ) -> Self {
        TransmissionMockStep(
            matcher: .method(method),
            response: .rpcSuccess(arguments: arguments, tag: tag),
            assertions: assertions,
            repeats: repeats
        )
    }

    /// Создает шаг с ошибочным Transmission RPC ответом.
    public static func rpcError(
        method: String,
        result: String,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        repeats: Int? = nil,
        assertions: [TransmissionMockAssertion] = []
    ) -> Self {
        TransmissionMockStep(
            matcher: .method(method),
            response: .rpcError(result: result, statusCode: statusCode, headers: headers),
            assertions: assertions,
            repeats: repeats
        )
    }

    /// Создает шаг, инжектирующий сетевую ошибку (`URLError`).
    public static func networkFailure(
        method: String,
        error: URLError,
        repeats: Int? = nil,
        assertions: [TransmissionMockAssertion] = []
    ) -> Self {
        TransmissionMockStep(
            matcher: .method(method),
            response: .network(error),
            assertions: assertions,
            repeats: repeats
        )
    }
}

public indirect enum TransmissionMockResponsePlan: Sendable {
    case rpcSuccess(arguments: AnyCodable? = nil, tag: TransmissionTag? = nil)
    case rpcError(result: String, statusCode: Int = 200, headers: [String: String] = [:])
    case http(statusCode: Int, headers: [String: String], body: Data? = nil)
    case network(_ error: URLError)
    case handshake(sessionID: String, followUp: TransmissionMockResponsePlan)
    case custom(
        _ builder:
            @Sendable (TransmissionRequest, URLRequest) throws -> TransmissionMockResponsePlan)
}

public struct TransmissionMockAssertion: Sendable {
    public let description: String
    public let evaluate: @Sendable (TransmissionRequest, URLRequest) throws -> Void

    public init(
        _ description: String,
        evaluate: @escaping @Sendable (TransmissionRequest, URLRequest) throws -> Void
    ) {
        self.description = description
        self.evaluate = evaluate
    }
}

private struct TransmissionMockPendingStep {
    let scenarioName: String
    let step: TransmissionMockStep
    var remaining: Int
}

// MARK: - Server

/// Мок-сервер может использоваться параллельно несколькими потоками тестов.
/// Состояние защищено `NSLock`, поэтому @unchecked применяется осознанно.
public final class TransmissionMockServer: @unchecked Sendable {
    nonisolated(unsafe) static var activeServer: TransmissionMockServer?
    static let activeServerLock: NSLock = NSLock()

    private let lock: NSLock = NSLock()
    private var pendingSteps: [TransmissionMockPendingStep] = []

    public init() {}

    public func register(scenario: TransmissionMockScenario) {
        lock.lock()
        for step in scenario.steps {
            let repeatCount: Int = max(step.repeats ?? 1, 1)
            pendingSteps.append(
                TransmissionMockPendingStep(
                    scenarioName: scenario.name,
                    step: step,
                    remaining: repeatCount
                )
            )
        }
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        pendingSteps.removeAll()
        lock.unlock()
    }

    public func deactivate() {
        TransmissionMockServer.activeServerLock.lock()
        if TransmissionMockServer.activeServer === self {
            TransmissionMockServer.activeServer = nil
        }
        TransmissionMockServer.activeServerLock.unlock()
    }

    public func makeEphemeralSessionConfiguration() -> URLSessionConfiguration {
        let configuration: URLSessionConfiguration = .ephemeral
        var classes: [AnyClass] = configuration.protocolClasses ?? []
        if !classes.contains(where: { $0 == TransmissionMockURLProtocol.self }) {
            classes.insert(TransmissionMockURLProtocol.self, at: 0)
        }
        configuration.protocolClasses = classes

        TransmissionMockServer.activeServerLock.lock()
        TransmissionMockServer.activeServer = self
        TransmissionMockServer.activeServerLock.unlock()

        return configuration
    }

    public func assertAllScenariosFinished() throws {
        lock.lock()
        let remaining: [TransmissionMockPendingStep] = pendingSteps
        lock.unlock()

        guard remaining.isEmpty else {
            let unresolved: String = remaining.map {
                "\($0.scenarioName) – матчер: \($0.step.matcher.description)"
            }.joined(separator: "; ")
            throw TransmissionMockError.unexpectedRequest(description: unresolved)
        }
    }

    fileprivate func consumeStep(
        for urlRequest: URLRequest,
        requestBody: Data
    ) throws -> (TransmissionMockPendingStep, TransmissionRequest) {
        let decoder: JSONDecoder = JSONDecoder()
        let transmissionRequest: TransmissionRequest
        do {
            transmissionRequest = try decoder.decode(TransmissionRequest.self, from: requestBody)
        } catch {
            throw TransmissionMockError.decodingFailed(error.localizedDescription)
        }

        lock.lock()
        defer { lock.unlock() }

        guard
            let index: Int = pendingSteps.firstIndex(where: {
                $0.step.matcher.matches(transmissionRequest, urlRequest)
            })
        else {
            let descriptions: [String] = pendingSteps.map {
                "\($0.scenarioName) – ожидаем: \($0.step.matcher.description)"
            }
            throw TransmissionMockError.unexpectedRequest(
                description:
                    """
                    method=\(transmissionRequest.method); ожидаемые шаги: \(descriptions.joined(separator: "; "))
                    """
            )
        }

        var pending: TransmissionMockPendingStep = pendingSteps[index]
        pending.remaining -= 1

        if pending.remaining <= 0 {
            pendingSteps.remove(at: index)
        } else {
            pendingSteps[index] = pending
        }

        return (pending, transmissionRequest)
    }

    fileprivate func prependContinuation(_ step: TransmissionMockStep, scenarioName: String) {
        lock.lock()
        pendingSteps.insert(
            TransmissionMockPendingStep(
                scenarioName: scenarioName,
                step: step,
                remaining: 1
            ),
            at: 0
        )
        lock.unlock()
    }
}

// MARK: - URLProtocol

final class TransmissionMockURLProtocol: URLProtocol {
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // swiftlint:disable function_body_length
    override func startLoading() {
        TransmissionMockServer.activeServerLock.lock()
        let server: TransmissionMockServer? = TransmissionMockServer.activeServer
        TransmissionMockServer.activeServerLock.unlock()

        guard let server else {
            client?.urlProtocol(self, didFailWithError: TransmissionMockError.serverNotRegistered)
            return
        }

        // Извлекаем тело запроса из httpBodyStream (приоритет) или httpBody
        var body: Data?

        // 1. Пробуем stream (основной путь, установлен TransmissionClient)
        if let stream = request.httpBodyStream {
            body = requestBody(from: stream)
        }

        // 2. Fallback на request.httpBody
        let shouldFallbackToHTTPBody = body == nil || body?.isEmpty == true
        if shouldFallbackToHTTPBody, let httpBody = request.httpBody, httpBody.isEmpty == false {
            body = httpBody
        }

        guard let requestBody = body, !requestBody.isEmpty else {
            let errorMessage = """
                Пустое тело запроса. 
                httpBody: \(request.httpBody?.count ?? 0) bytes
                httpBodyStream: \(request.httpBodyStream != nil)
                URL: \(request.url?.absoluteString ?? "nil")
                """
            client?.urlProtocol(
                self,
                didFailWithError: TransmissionMockError.decodingFailed(errorMessage)
            )
            return
        }

        do {
            let (pending, transmissionRequest): (TransmissionMockPendingStep, TransmissionRequest) =
                try server
                .consumeStep(
                    for: request,
                    requestBody: requestBody
                )

            print(
                "🔍 MockServer: method=\(transmissionRequest.method), assertions=\(pending.step.assertions.count)"
            )

            for assertion in pending.step.assertions {
                do {
                    try assertion.evaluate(transmissionRequest, request)
                } catch {
                    print("❌ Assertion failed: \(assertion.description) - \(error)")
                    throw TransmissionMockError.assertionFailed(
                        "\(assertion.description): \(error.localizedDescription)"
                    )
                }
            }

            try handle(
                plan: pending.step.response, pending: pending, request: transmissionRequest,
                server: server)
        } catch {
            print("❌ MockServer error: \(error)")
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    // swiftlint:enable function_body_length

    override func stopLoading() {}

    private func handle(
        plan: TransmissionMockResponsePlan,
        pending: TransmissionMockPendingStep,
        request: TransmissionRequest,
        server: TransmissionMockServer
    ) throws {
        switch plan {
        case .rpcSuccess(let arguments, let tag):
            try sendRPCResponse(
                result: "success",
                arguments: arguments,
                tag: tag ?? request.tag
            )

        case .rpcError(let result, let statusCode, let headers):
            try sendRPCResponse(
                result: result,
                arguments: nil,
                tag: request.tag,
                statusCode: statusCode,
                headers: headers
            )

        case .http(let statusCode, let headers, let body):
            sendHTTP(statusCode: statusCode, headers: headers, body: body)

        case .network(let error):
            client?.urlProtocol(self, didFailWithError: error)

        case .handshake(let sessionID, let followUp):
            sendHandshake(sessionID: sessionID)
            let continuation: TransmissionMockStep = pending.step.copy(with: followUp)
            server.prependContinuation(continuation, scenarioName: pending.scenarioName)

        case .custom(let builder):
            let nextPlan: TransmissionMockResponsePlan = try builder(request, self.request)
            try handle(plan: nextPlan, pending: pending, request: request, server: server)
        }
    }

    private func sendRPCResponse(
        result: String,
        arguments: AnyCodable?,
        tag: TransmissionTag?,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) throws {
        let responseModel: TransmissionResponse = TransmissionResponse(
            result: result,
            arguments: arguments,
            tag: tag
        )
        let data: Data = try JSONEncoder().encode(responseModel)
        sendHTTP(
            statusCode: statusCode,
            headers: headers.merging(["Content-Type": "application/json"]) { current, _ in current
            },
            body: data
        )
    }

    private func sendHandshake(sessionID: String) {
        sendHTTP(
            statusCode: 409,
            headers: [
                "Content-Type": "application/json",
                "X-Transmission-Session-Id": sessionID
            ],
            body: Data()
        )
    }

    private func sendHTTP(
        statusCode: Int,
        headers: [String: String],
        body: Data?
    ) {
        guard let url: URL = request.url else {
            client?.urlProtocol(
                self,
                didFailWithError: TransmissionMockError.unexpectedRequest(
                    description: "Отсутствует URL"))
            return
        }

        let response: HTTPURLResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let body {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func requestBody(from stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }

        let bufferSize: Int = 1024
        var data: Data = Data()
        var buffer: [UInt8] = Array(repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let read: Int = stream.read(&buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }

        return data.isEmpty ? nil : data
    }
}
