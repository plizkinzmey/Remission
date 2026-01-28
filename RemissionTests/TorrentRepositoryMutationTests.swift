import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Mutation")
struct TorrentRepositoryMutationTests {
    @Test("makeAddClosure передаёт параметры magnet и маппит added")
    func addClosureMapsAddedTorrent() async throws {
        // Тест проверяет, что magnet отправляется в filename, а metainfo остаётся nil,
        // и что mapper корректно возвращает .added с нужными полями.
        let magnetURL = try #require(URL(string: "magnet:?xt=urn:btih:123"))
        let input = PendingTorrentInput(
            payload: .magnetLink(url: magnetURL, rawValue: magnetURL.absoluteString),
            sourceDescription: "test"
        )
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-add.success.magnet.json"
        )
        let recorder = AddRecorder()

        let client = makeClient(
            torrentAdd: { filename, metainfo, downloadDir, paused, labels in
                await recorder.record(
                    filename: filename,
                    metainfo: metainfo,
                    downloadDir: downloadDir,
                    paused: paused,
                    labels: labels
                )
                return response
            }
        )

        let closure = TorrentRepository.makeAddClosure(
            client: client,
            mapper: TransmissionDomainMapper()
        )

        let result = try await closure(input, "/downloads", true, ["linux"])

        #expect(await recorder.filename == magnetURL.absoluteString)
        #expect(await recorder.metainfo == nil)
        #expect(await recorder.downloadDir == "/downloads")
        #expect(await recorder.paused == true)
        #expect(await recorder.labels == ["linux"])

        #expect(result.status == .added)
        #expect(result.id.rawValue == 8)
        #expect(result.name == "Fedora-Workstation-Live-x86_64-40")
    }

    @Test("makeAddClosure маппит duplicate при повторном добавлении")
    func addClosureMapsDuplicateTorrent() async throws {
        // Важно отличать duplicate от added, иначе UI покажет неверное состояние.
        let magnetURL = try #require(URL(string: "magnet:?xt=urn:btih:duplicate"))
        let input = PendingTorrentInput(
            payload: .magnetLink(url: magnetURL, rawValue: magnetURL.absoluteString),
            sourceDescription: "test"
        )
        let response = try TransmissionFixtureLoader.loadResponse(
            "Torrents/torrent-add.duplicate.magnet.json"
        )

        let client = makeClient(
            torrentAdd: { _, _, _, _, _ in response }
        )

        let closure = TorrentRepository.makeAddClosure(
            client: client,
            mapper: TransmissionDomainMapper()
        )

        let result = try await closure(input, "/downloads", false, nil)

        #expect(result.status == .duplicate)
        #expect(result.id.rawValue == 9)
        #expect(result.name == "Fedora-Workstation-Live-x86_64-40")
    }

    @Test("makeUpdateTransferSettingsClosure не вызывает torrentSet при пустых настройках")
    func updateTransferSettingsNoopWhenEmpty() async throws {
        // Этот тест защищает от лишних RPC-вызовов: пустые настройки не должны
        // отправлять запрос и загружать сеть.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let closure = TorrentRepository.makeUpdateTransferSettingsClosure(client: client)
        try await closure(.init(), [.init(rawValue: 1)])

        #expect(await recorder.callCount == 0)
    }

    @Test("makeUpdateTransferSettingsClosure отправляет корректные аргументы")
    func updateTransferSettingsSendsArguments() async throws {
        // Проверяем корректное формирование RPC-аргументов для лимитов.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let settings = TorrentRepository.TransferSettings(
            downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 512),
            uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 128)
        )

        let closure = TorrentRepository.makeUpdateTransferSettingsClosure(client: client)
        try await closure(settings, [.init(rawValue: 7), .init(rawValue: 8)])

        #expect(await recorder.ids == [7, 8])
        #expect(
            await recorder.arguments
                == .object([
                    "downloadLimit": .int(512),
                    "downloadLimited": .bool(true),
                    "uploadLimit": .int(128),
                    "uploadLimited": .bool(false)
                ]))
    }

    @Test("makeUpdateLabelsClosure не вызывает torrentSet при пустом списке")
    func updateLabelsNoopWhenEmpty() async throws {
        // Пустые теги — валидный сценарий, но он не должен запускать RPC.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let closure = TorrentRepository.makeUpdateLabelsClosure(client: client)
        try await closure([], [.init(rawValue: 1)])

        #expect(await recorder.callCount == 0)
    }

    @Test("makeUpdateLabelsClosure передаёт labels и ID")
    func updateLabelsSendsLabels() async throws {
        // Этот тест фиксирует структуру RPC: labels обязаны уходить массивом строк.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let closure = TorrentRepository.makeUpdateLabelsClosure(client: client)
        try await closure(["movies", "linux"], [.init(rawValue: 3)])

        #expect(await recorder.ids == [3])
        #expect(
            await recorder.arguments
                == .object([
                    "labels": .array([
                        .string("movies"),
                        .string("linux")
                    ])
                ]))
    }

    @Test("makeUpdateFileSelectionClosure не вызывает torrentSet без изменений")
    func updateFileSelectionNoopWhenNoChanges() async throws {
        // Если нет изменений wanted/priority, мы не должны отправлять запрос.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let closure = TorrentRepository.makeUpdateFileSelectionClosure(client: client)
        try await closure([.init(fileIndex: 0)], .init(rawValue: 5))

        #expect(await recorder.callCount == 0)
    }

    @Test("makeUpdateFileSelectionClosure формирует аргументы и отправляет torrentSet")
    func updateFileSelectionSendsArguments() async throws {
        // Проверяем, что wanted и priority корректно конвертируются в RPC-ключи.
        let recorder = SetRecorder()
        let client = makeClient(
            torrentSet: { ids, arguments in
                await recorder.record(ids: ids, arguments: arguments)
                return TransmissionResponse(result: "success")
            }
        )

        let updates: [TorrentRepository.FileSelectionUpdate] = [
            .init(fileIndex: 0, isWanted: true, priority: .high),
            .init(fileIndex: 2, isWanted: false, priority: .low)
        ]

        let closure = TorrentRepository.makeUpdateFileSelectionClosure(client: client)
        try await closure(updates, .init(rawValue: 99))

        #expect(await recorder.ids == [99])
        #expect(
            await recorder.arguments
                == .object([
                    "files-wanted": .array([.int(0)]),
                    "files-unwanted": .array([.int(2)]),
                    "priority-high": .array([.int(0)]),
                    "priority-low": .array([.int(2)])
                ]))
    }
}

private actor AddRecorder {
    private(set) var filename: String?
    private(set) var metainfo: Data?
    private(set) var downloadDir: String?
    private(set) var paused: Bool?
    private(set) var labels: [String]?

    func record(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) {
        self.filename = filename
        self.metainfo = metainfo
        self.downloadDir = downloadDir
        self.paused = paused
        self.labels = labels
    }
}

private actor SetRecorder {
    private(set) var ids: [Int]?
    private(set) var arguments: AnyCodable?
    private(set) var callCount: Int = 0

    func record(ids: [Int], arguments: AnyCodable) {
        self.ids = ids
        self.arguments = arguments
        callCount += 1
    }
}

private func makeClient(
    torrentAdd:
        @escaping @Sendable (
            String?, Data?, String?, Bool?, [String]?
        ) async throws -> TransmissionResponse = { _, _, _, _, _ in fatalError("unused in tests") },
    torrentSet: @escaping @Sendable ([Int], AnyCodable) async throws -> TransmissionResponse =
        { _, _ in fatalError("unused in tests") }
) -> TransmissionClientDependency {
    TransmissionClientDependency(
        sessionGet: { fatalError("unused in tests") },
        sessionSet: { _ in fatalError("unused in tests") },
        sessionStats: { fatalError("unused in tests") },
        freeSpace: { _ in fatalError("unused in tests") },
        torrentGet: { _, _ in fatalError("unused in tests") },
        torrentAdd: torrentAdd,
        torrentStart: { _ in fatalError("unused in tests") },
        torrentStop: { _ in fatalError("unused in tests") },
        torrentRemove: { _, _ in fatalError("unused in tests") },
        torrentSet: torrentSet,
        torrentVerify: { _ in fatalError("unused in tests") },
        checkServerVersion: { fatalError("unused in tests") },
        performHandshake: { fatalError("unused in tests") },
        setTrustDecisionHandler: { _ in }
    )
}
