import Foundation
import Testing

@testable import Remission

@Suite("TransmissionMockServer")
struct TransmissionMockServerTests {
    private func makeClient(using server: TransmissionMockServer) -> TransmissionClient {
        let config: URLSessionConfiguration = server.makeEphemeralSessionConfiguration()
        let session: URLSession = URLSession(configuration: config)
        let clientConfig: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "https://mock.transmission/app")!,
            requestTimeout: 3,
            maxRetries: 0,
            enableLogging: false
        )
        return TransmissionClient(config: clientConfig, session: session)
    }

    @Test("handshake + success сценарий возвращает ожидаемые данные")
    func testHandshakeScenario() async throws {
        let arguments: AnyCodable = .object([
            "rpc-version": .int(20),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.3")
        ])

        let mockServer: TransmissionMockServer = TransmissionMockServer()
        mockServer.register(
            scenario: .init(
                name: "Handshake success",
                steps: [
                    .init(
                        matcher: .method("session-get"),
                        response: .handshake(
                            sessionID: "mock-session",
                            followUp: .rpcSuccess(arguments: arguments)
                        )
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)
        let response: TransmissionResponse = try await client.sessionGet()

        #expect(response.isSuccess)
        #expect(response.arguments?.objectValue?["rpc-version"] == .int(20))
        try mockServer.assertAllScenariosFinished()
    }

    @Test("неожиданный метод приводит к TransmissionMockError.unexpectedRequest")
    func testUnexpectedRequest() async {
        let mockServer: TransmissionMockServer = TransmissionMockServer()
        mockServer.register(
            scenario: .init(
                name: "Expect torrent-get",
                steps: [
                    .init(
                        matcher: .method("torrent-get"),
                        response: .rpcSuccess(arguments: nil)
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Ожидалась ошибка unexpectedRequest")
        } catch let apiError as APIError {
            switch apiError {
            case .unknown:
                #expect(true)
            default:
                #expect(Bool(false), "Ожидалась APIError.unknown, получено \(apiError)")
            }
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }

        do {
            try mockServer.assertAllScenariosFinished()
            #expect(Bool(false), "assertAllScenariosFinished должен сообщить об оставшихся шагах")
        } catch let error as TransmissionMockError {
            if case .unexpectedRequest = error {
                #expect(true)
            } else {
                #expect(
                    Bool(false),
                    "Ожидался TransmissionMockError.unexpectedRequest, получено \(error)")
            }
        } catch {
            #expect(Bool(false), "Ожидался TransmissionMockError, получено \(error)")
        }
    }

    @Test("rpcError мапится в APIError.mapTransmissionError")
    func testRpcErrorMapsToApiError() async {
        let mockServer: TransmissionMockServer = TransmissionMockServer()
        mockServer.register(
            scenario: .init(
                name: "RPC error",
                steps: [
                    .init(
                        matcher: .method("session-get"),
                        response: .rpcError(result: "too many recent requests")
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)

        do {
            _ = try await client.sessionGet()
            #expect(Bool(false), "Ожидалась ошибка APIError.unknown при result != success")
        } catch let apiError as APIError {
            #expect(apiError == .unknown(details: "too many recent requests"))
        } catch {
            #expect(Bool(false), "Ожидалась APIError, получено \(error)")
        }
    }

    @Test("repeats потребляет шаг заданное количество раз")
    func testRepeatedSteps() async throws {
        let torrentsArguments: AnyCodable = .object([
            "torrents": .array([
                .object(["id": .int(1), "name": .string("Test Torrent")])
            ])
        ])

        let mockServer: TransmissionMockServer = TransmissionMockServer()
        mockServer.register(
            scenario: .init(
                name: "Polling torrent-get",
                steps: [
                    .init(
                        matcher: .method("torrent-get"),
                        response: .rpcSuccess(arguments: torrentsArguments),
                        repeats: 2
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)

        let first: TransmissionResponse = try await client.torrentGet(ids: nil, fields: nil)
        let second: TransmissionResponse = try await client.torrentGet(ids: nil, fields: nil)

        #expect(first.isSuccess)
        #expect(second.isSuccess)
        try mockServer.assertAllScenariosFinished()
    }
}
