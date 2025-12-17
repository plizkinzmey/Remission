import Clocks
import Foundation
import Testing

@testable import Remission

private let fixturesBaseURL = URL(string: "https://mock.transmission/rpc")!

// TransmissionClient успешные сценарии — с использованием фикстур
//
// Интеграционные тесты, которые используют:
// - Mock-сервер (`TransmissionMockServer`) для эмуляции Transmission RPC (RTC-29)
// - Фикстуры (`TransmissionFixture`) с реальными ответами (RTC-30)
// - Полный цикл handshake: HTTP 409 → session-id extraction → повторный запрос
//
// **Архитектура тестов:**
// 1. Регистрируем сценарий в mock-сервере
// 2. Проверяем аргументы запроса через assertions
// 3. Возвращаем фикстуру в качестве ответа
// 4. Парсим и валидируем ответ через `#expect`/`#require`
//
// **Справочные материалы:**
// - Swift Testing: https://developer.apple.com/documentation/testing
// - Transmission RPC Spec: devdoc/TRANSMISSION_RPC_REFERENCE.md
// - Mock-сервер (RTC-29): RemissionTests/TransmissionMockServer.swift
// - Фикстуры (RTC-30): RemissionTests/Fixtures/TransmissionFixture.swift
//
// swiftlint:disable explicit_type_interface
@Suite("TransmissionClient Happy Path (Fixtures)", .serialized)
@MainActor
struct TransmissionClientHappyPathFixturesTests {
    // MARK: - Tests

    // swiftlint:disable function_body_length
    @Test("torrent-get возвращает данные из фикстуры и сохраняет session-id")
    func testTorrentGetSuccessWithFixture() async throws {
        let expectedResponse: TransmissionResponse =
            try TransmissionFixture.response(.torrentGetSingleActive)
        let sessionID: String = "session-torrent-get"
        let mockServer: TransmissionMockServer = TransmissionMockServer()

        mockServer.register(
            scenario: TransmissionMockScenario(
                name: "torrent-get success",
                steps: [
                    handshakeStep(
                        method: "torrent-get",
                        sessionID: sessionID,
                        fixture: .torrentGetSingleActive,
                        assertions: [
                            TransmissionMockAssertion("encodes ids and fields") { request, _ in
                                let arguments = try argumentsDictionary(from: request)
                                guard
                                    arguments["ids"]
                                        == .array([.int(1), .int(2)])
                                else {
                                    throw TransmissionMockError.assertionFailed(
                                        "ids аргумент передан некорректно")
                                }
                                guard
                                    arguments["fields"]
                                        == .array([.string("id"), .string("name")])
                                else {
                                    throw TransmissionMockError.assertionFailed(
                                        "fields аргумент передан некорректно")
                                }
                            }
                        ]
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)
        let response: TransmissionResponse =
            try await client.torrentGet(ids: [1, 2], fields: ["id", "name"])

        #expect(response == expectedResponse)

        let torrents: [AnyCodable] =
            try #require(
                response.arguments?
                    .objectValue?["torrents"]?
                    .arrayValue,
                "Ожидался массив torrents в ответе"
            )
        #expect(torrents.count == 1)
        let torrent = torrents[0]
        let torrentInfo = try #require(
            torrent.objectValue,
            "Ожидался словарь торрента"
        )
        #expect(torrentInfo["id"] == .int(7))
        #expect(torrentInfo["name"] == .string("Ubuntu 24.04 LTS"))
        #expect(torrentInfo["status"] == .int(4))

        try mockServer.assertAllScenariosFinished()
    }

    // swiftlint:enable function_body_length

    // swiftlint:disable function_body_length
    @Test("torrent-add возвращает torrent-added из фикстуры")
    func testTorrentAddSuccessWithFixture() async throws {
        let expectedResponse: TransmissionResponse =
            try TransmissionFixture.response(.torrentAddSuccessMagnet)
        let sessionID: String = "session-torrent-add"
        let mockServer: TransmissionMockServer = TransmissionMockServer()

        mockServer.register(
            scenario: TransmissionMockScenario(
                name: "torrent-add success",
                steps: [
                    handshakeStep(
                        method: "torrent-add",
                        sessionID: sessionID,
                        fixture: .torrentAddSuccessMagnet,
                        assertions: [
                            TransmissionMockAssertion("encodes magnet payload") { request, _ in
                                let arguments = try argumentsDictionary(from: request)
                                guard
                                    arguments["filename"]
                                        == .string("magnet:?xt=urn:btih:deadbeef")
                                else {
                                    throw TransmissionMockError.assertionFailed(
                                        "Ожидался magnet в filename")
                                }
                                guard arguments["paused"] == .bool(true) else {
                                    throw TransmissionMockError.assertionFailed(
                                        "Ожидался paused == true")
                                }
                            }
                        ]
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)
        let response: TransmissionResponse = try await client.torrentAdd(
            filename: "magnet:?xt=urn:btih:deadbeef",
            metainfo: nil,
            downloadDir: "/downloads",
            paused: true,
            labels: ["linux"]
        )

        #expect(response == expectedResponse)

        let torrentAdded: [String: AnyCodable] =
            try #require(
                response.arguments?
                    .objectValue?["torrent-added"]?
                    .objectValue,
                "Ожидались данные torrent-added"
            )
        #expect(torrentAdded["id"] == .int(8))
        #expect(torrentAdded["name"] == .string("Fedora-Workstation-Live-x86_64-40"))

        try mockServer.assertAllScenariosFinished()
    }
    // swiftlint:enable function_body_length

    @Test("torrent-add возвращает torrent-duplicate из фикстуры")
    func testTorrentAddDuplicateWithFixture() async throws {
        let expectedResponse: TransmissionResponse =
            try TransmissionFixture.response(.torrentAddDuplicateMagnet)
        let sessionID: String = "session-torrent-duplicate"
        let mockServer: TransmissionMockServer = TransmissionMockServer()

        mockServer.register(
            scenario: TransmissionMockScenario(
                name: "torrent-add duplicate",
                steps: [
                    handshakeStep(
                        method: "torrent-add",
                        sessionID: sessionID,
                        fixture: .torrentAddDuplicateMagnet,
                        assertions: [
                            TransmissionMockAssertion("encodes magnet payload") { request, _ in
                                let arguments = try argumentsDictionary(from: request)
                                guard
                                    arguments["filename"]
                                        == .string("magnet:?xt=urn:btih:duplicate")
                                else {
                                    throw TransmissionMockError.assertionFailed(
                                        "Ожидался magnet в filename")
                                }
                            }
                        ]
                    )
                ]
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)
        let response: TransmissionResponse = try await client.torrentAdd(
            filename: "magnet:?xt=urn:btih:duplicate",
            metainfo: nil,
            downloadDir: "/downloads",
            paused: false,
            labels: nil
        )

        #expect(response == expectedResponse)
        let torrentDuplicate: [String: AnyCodable] =
            try #require(
                response.arguments?
                    .objectValue?["torrent-duplicate"]?
                    .objectValue,
                "Ожидались данные torrent-duplicate"
            )
        #expect(torrentDuplicate["id"] == .int(9))

        try mockServer.assertAllScenariosFinished()
    }

    @Test("torrent-start использует session-id и возвращает success")
    func testTorrentStartSuccessWithFixture() async throws {
        try await assertSimpleCommandSuccess(
            method: "torrent-start",
            fixture: .torrentStartSuccess,
            sessionID: "session-torrent-start",
            perform: { client in
                try await client.torrentStart(ids: [10, 11, 12])
            },
            validateArguments: { request in
                let arguments = try argumentsDictionary(from: request)
                guard
                    arguments["ids"]
                        == .array([.int(10), .int(11), .int(12)])
                else {
                    throw TransmissionMockError.assertionFailed("ids переданы неверно")
                }
            }
        )
    }

    @Test("torrent-stop использует session-id и возвращает success")
    func testTorrentStopSuccessWithFixture() async throws {
        try await assertSimpleCommandSuccess(
            method: "torrent-stop",
            fixture: .torrentStopSuccess,
            sessionID: "session-torrent-stop",
            perform: { client in
                try await client.torrentStop(ids: [15])
            },
            validateArguments: { request in
                let arguments = try argumentsDictionary(from: request)
                guard arguments["ids"] == .array([.int(15)]) else {
                    throw TransmissionMockError.assertionFailed("ids переданы неверно")
                }
            }
        )
    }

    @Test("torrent-remove кодирует delete-local-data и возвращает success")
    func testTorrentRemoveSuccessWithFixture() async throws {
        try await assertSimpleCommandSuccess(
            method: "torrent-remove",
            fixture: .torrentRemoveSuccessDeleteData,
            sessionID: "session-torrent-remove",
            perform: { client in
                try await client.torrentRemove(ids: [21, 22], deleteLocalData: true)
            },
            validateArguments: { request in
                let arguments = try argumentsDictionary(from: request)
                guard arguments["ids"] == .array([.int(21), .int(22)]) else {
                    throw TransmissionMockError.assertionFailed("ids переданы неверно")
                }
                guard arguments["delete-local-data"] == .bool(true) else {
                    throw TransmissionMockError.assertionFailed(
                        "delete-local-data должен быть true")
                }
            }
        )
    }

    @Test("torrent-get потокобезопасно обрабатывает параллельные запросы")
    func testTorrentGetIsThreadSafeUnderConcurrency() async throws {
        let requestCount: Int = 8
        let sessionID: String = "session-concurrent"
        let mockServer: TransmissionMockServer = TransmissionMockServer()

        mockServer.register(
            scenario: TransmissionMockScenario(
                name: "session-get handshake",
                steps: [
                    handshakeStep(
                        method: "session-get",
                        sessionID: sessionID,
                        fixture: .sessionGetSuccessRPC17
                    )
                ]
            )
        )

        let torrentGetSteps: [TransmissionMockStep] = (0..<requestCount).map { _ in
            TransmissionMockStep(
                matcher: .method("torrent-get"),
                response: .custom { _, urlRequest in
                    try assertSessionHeader(in: urlRequest, equals: sessionID)
                    return try TransmissionMockResponsePlan.fixture(.torrentGetSingleActive)
                }
            )
        }

        mockServer.register(
            scenario: TransmissionMockScenario(
                name: "concurrent torrent-get",
                steps: torrentGetSteps
            )
        )

        let client: TransmissionClient = makeClient(using: mockServer)
        _ = try await client.performHandshake()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<requestCount {
                group.addTask {
                    _ = try await client.torrentGet(ids: [index], fields: ["id"])
                }
            }
            try await group.waitForAll()
        }

        try mockServer.assertAllScenariosFinished()
    }

}

private func argumentsDictionary(from request: TransmissionRequest) throws -> [String: AnyCodable] {
    guard let arguments = request.arguments?.objectValue else {
        throw TransmissionMockError.assertionFailed("Ожидались arguments в TransmissionRequest")
    }
    return arguments
}

private func assertSessionHeader(in urlRequest: URLRequest, equals sessionID: String) throws {
    guard
        let header = urlRequest.value(forHTTPHeaderField: "X-Transmission-Session-Id"),
        header == sessionID
    else {
        throw TransmissionMockError.assertionFailed(
            "Ожидался заголовок X-Transmission-Session-Id == \(sessionID)"
        )
    }
}

private func makeClient(using server: TransmissionMockServer) -> TransmissionClient {
    let configuration: URLSessionConfiguration = server.makeEphemeralSessionConfiguration()
    let config: TransmissionClientConfig = TransmissionClientConfig(
        baseURL: fixturesBaseURL,
        requestTimeout: 5,
        maxRetries: 0,
        enableLogging: false
    )
    let immediateClock = ImmediateClock()
    return TransmissionClient(
        config: config,
        sessionConfiguration: configuration,
        trustStore: .inMemory(),
        trustDecisionHandler: { _ in .trustPermanently },
        clock: immediateClock
    )
}

private func handshakeStep(
    method: String,
    sessionID: String,
    fixture: TransmissionFixtureName,
    assertions: [TransmissionMockAssertion] = [],
    repeats: Int? = nil
) -> TransmissionMockStep {
    TransmissionMockStep(
        matcher: .method(method),
        response: .handshake(
            sessionID: sessionID,
            followUp: .custom { _, urlRequest in
                try assertSessionHeader(in: urlRequest, equals: sessionID)
                return try TransmissionMockResponsePlan.fixture(fixture)
            }
        ),
        assertions: assertions,
        repeats: repeats
    )
}

private func assertSimpleCommandSuccess(
    method: String,
    fixture: TransmissionFixtureName,
    sessionID: String,
    perform: @Sendable (TransmissionClient) async throws -> TransmissionResponse,
    validateArguments: @escaping @Sendable (TransmissionRequest) throws -> Void
) async throws {
    let expectedResponse: TransmissionResponse = try TransmissionFixture.response(fixture)
    let mockServer: TransmissionMockServer = TransmissionMockServer()

    mockServer.register(
        scenario: TransmissionMockScenario(
            name: "\(method) success",
            steps: [
                handshakeStep(
                    method: method,
                    sessionID: sessionID,
                    fixture: fixture,
                    assertions: [
                        TransmissionMockAssertion("validates request arguments") { request, _ in
                            try validateArguments(request)
                        }
                    ]
                )
            ]
        )
    )

    let client: TransmissionClient = makeClient(using: mockServer)
    let response: TransmissionResponse = try await perform(client)

    #expect(response == expectedResponse)
    try mockServer.assertAllScenariosFinished()
}

// swiftlint:enable explicit_type_interface
