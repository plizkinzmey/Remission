import Clocks
import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClient Error Handling")
@MainActor
// swiftlint:disable:next type_body_length
struct TransmissionClientErrorHandlingTests {
    private let baseURL = URL(string: "http://example.com/transmission/rpc")!

    @Test("возвращает decodingFailed при пустом ответе")
    func testEmptyResponseBodyProducesDecodingFailed() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка decodingFailed при пустом ответе")
        } catch let error as APIError {
            if case .decodingFailed(let message) = error {
                #expect(message == "Empty response body")
            } else {
                #expect(Bool(false), "Ожидалась decodingFailed, получено \(error)")
            }
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("маппит DecodingError в APIError.decodingFailed")
    func testInvalidJSONMapsToDecodingFailed() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("not-json".utf8))
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка decodingFailed при невалидном JSON")
        } catch let error as APIError {
            if case .decodingFailed(let message) = error {
                #expect(message.contains("Data corrupted") || message.contains("Cannot decode"))
            } else {
                #expect(Bool(false), "Ожидалась decodingFailed, получено \(error)")
            }
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("ретраит запрос при session-conflict и использует session-id")
    func testSessionConflictRetry() async throws {
        let sessionResponse = TransmissionResponse(result: "success")

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-123"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(sessionResponse)
                return (response, data)
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)
        let response = try await client.torrentStart(ids: [1])
        #expect(response == sessionResponse)
        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-123")
    }

    @Test("session-conflict обрабатывается даже при maxRetries = 0")
    func testSessionConflictRetryWithoutAdditionalRetries() async throws {
        let sessionResponse = TransmissionResponse(result: "success")

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-456"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(sessionResponse)
                return (response, data)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            maxRetries: 0
        )
        let (client, _) = makeTransmissionClient(baseURL: baseURL, config: config)
        let response = try await client.sessionStats()
        #expect(response == sessionResponse)
        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-456")
    }

    @Test("session-conflict без заголовка session-id приводит к ошибке")
    func testSessionConflictMissingHeader() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: [:]
                )!
                return (response, Data())
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.sessionStats()
            #expect(Bool(false), "Ожидалась ошибка sessionConflict при отсутствии заголовка")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("ограничивает количество handshake ретраев при повторных 409")
    func testHandshakeRetryLimit() async throws {
        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-A"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-B"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-C"]
                )!
                return (response, Data())
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Ожидалась APIError.sessionConflict после 3 попыток")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
            #expect(MockURLProtocol.requests.count == 3)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("performHandshake возвращает результат после успешного рукопожатия")
    func testPerformHandshakeSuccess() async throws {
        let handshakePayload: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "rpc-version": .int(17),
                "version": .string("4.0.0")
            ])
        )

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Transmission-Session-Id": "session-handshake"]
                )!
                return (response, Data())
            },
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(handshakePayload)
                return (response, data)
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)
        let result = try await client.performHandshake()

        #expect(MockURLProtocol.requests.count == 2)
        #expect(
            MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id")
                == "session-handshake")
        #expect(result.sessionID == "session-handshake")
        #expect(result.rpcVersion == 17)
        #expect(result.isCompatible == true)
        #expect(result.serverVersionDescription == "4.0.0")
    }

    @Test("performHandshake выбрасывает versionUnsupported при старой версии")
    func testPerformHandshakeVersionUnsupported() async throws {
        let handshakePayload: TransmissionResponse = TransmissionResponse(
            result: "success",
            arguments: .object([
                "rpc-version": .int(13),
                "version": .string("2.94")
            ])
        )

        MockURLProtocol.setHandlers([
            { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = try JSONEncoder().encode(handshakePayload)
                return (response, data)
            }
        ])

        let (client, _) = makeTransmissionClient(baseURL: baseURL)

        do {
            _ = try await client.performHandshake()
            Issue.record("Ожидалась версия unsupported")
        } catch let error as APIError {
            if case .versionUnsupported(let version) = error {
                #expect(version.contains("2.94") || version.contains("13"))
            } else {
                Issue.record("Ожидалась APIError.versionUnsupported, получено \(error)")
            }
        }
    }

    @Test("ограничивает ретраи для не повторяемых URLError")
    func testNonRetryableURLError() async throws {
        MockURLProtocol.setHandlers([
            { _ in
                throw URLError(.unsupportedURL)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            requestTimeout: 5,
            maxRetries: 3,
            retryDelay: 0.01
        )
        let (client, _) = makeTransmissionClient(baseURL: baseURL, config: config)

        do {
            _ = try await client.torrentGet(ids: nil, fields: nil)
            #expect(Bool(false), "Ожидалась ошибка при URLError(.unsupportedURL)")
        } catch let error as APIError {
            let expectedError = APIError.mapURLError(URLError(.unsupportedURL))
            #expect(error == expectedError)
            #expect(MockURLProtocol.requests.count == 1)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("ретраит временные URLError и в итоге пробрасывает APIError")
    func testRetryableURLErrorExhaustsRetries() async throws {
        var attempt = 0
        MockURLProtocol.setHandlers([
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            },
            { _ in
                attempt += 1
                throw URLError(.timedOut)
            }
        ])

        let config = TransmissionClientConfig(
            baseURL: baseURL,
            requestTimeout: 5,
            maxRetries: 3,
            retryDelay: 0.001
        )
        let (client, clock) = makeTransmissionClient(baseURL: baseURL, config: config)

        do {
            async let response = client.torrentGet(ids: nil, fields: nil)
            await clock.advance(by: .milliseconds(1))
            await clock.run()
            await clock.advance(by: .milliseconds(2))
            await clock.run()
            await clock.advance(by: .milliseconds(4))
            await clock.run()
            _ = try await response
            #expect(Bool(false), "Ожидалась ошибка после исчерпания ретраев")
        } catch let error as APIError {
            #expect(error == .networkUnavailable)
            #expect(attempt == 4)
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }
}
