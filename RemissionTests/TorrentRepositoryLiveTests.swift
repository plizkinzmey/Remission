import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository liveValue")
struct TorrentRepositoryLiveTests {
    private let mapper = TransmissionDomainMapper()

    @Test("fetchList выполняет RPC и мапит результат")
    func fetchListSuccess() async throws {
        let response = try TransmissionFixture.response(.torrentGetSingleActive)
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        let capturedFields = LockedValue<[String]?>(nil)
        client.torrentGet = { ids, fields in
            capturedIds.set(ids)
            capturedFields.set(fields)
            return response
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        let torrents = try await repository.fetchList()

        #expect(torrents.count == 1)
        let torrent: Torrent = try #require(torrents.first)
        #expect(torrent.name == "Ubuntu 24.04 LTS")
        #expect(capturedIds.value == nil)
        #expect(capturedFields.value == TorrentListFields.summary)
    }

    @Test("fetchList корректно обрабатывает пустой список")
    func fetchListEmptyList() async throws {
        var client = TransmissionClientDependency.placeholder
        client.torrentGet = { _, _ in
            TransmissionResponse(
                result: "success",
                arguments: .object(["torrents": .array([])])
            )
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        let torrents = try await repository.fetchList()

        #expect(torrents.isEmpty)
    }

    @Test("fetchList пробрасывает DomainMappingError.rpcError при ошибке RPC")
    func fetchListRpcError() async {
        var client = TransmissionClientDependency.placeholder
        client.torrentGet = { _, _ in
            TransmissionResponse(result: "error: unauthorized")
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        await #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "torrent-get"
            )
        ) {
            _ = try await repository.fetchList()
        }
    }

    @Test("fetchDetails выполняет RPC и мапит результат")
    func fetchDetailsSuccess() async throws {
        let response = try TransmissionFixture.response(.torrentGetSingleActive)
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        let capturedFields = LockedValue<[String]?>(nil)
        client.torrentGet = { ids, fields in
            capturedIds.set(ids)
            capturedFields.set(fields)
            return response
        }

        let repository = TorrentRepository.live(
            transmissionClient: client,
            mapper: mapper
        )

        let expectedID: Torrent.Identifier = .init(rawValue: 7)
        let details = try await repository.fetchDetails(expectedID)

        #expect(details.id == expectedID)
        #expect(details.details != nil)
        #expect(capturedIds.value == [expectedID.rawValue])
        #expect(capturedFields.value == TorrentListFields.details)
    }

    @Test("start выполняет команду и проверяет успех RPC")
    func startSuccess() async throws {
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        client.torrentStart = { ids in
            capturedIds.set(ids)
            return TransmissionResponse(result: "success")
        }

        let repository = TorrentRepository.live(transmissionClient: client)

        try await repository.start([.init(rawValue: 99)])

        #expect(capturedIds.value == [99])
    }

    @Test("start пробрасывает ошибку RPC")
    func startFailure() async {
        var client = TransmissionClientDependency.placeholder
        client.torrentStart = { _ in
            TransmissionResponse(result: "error: unauthorized")
        }

        let repository = TorrentRepository.live(transmissionClient: client)

        await #expect(
            throws: DomainMappingError.rpcError(
                result: "error: unauthorized",
                context: "torrent-start"
            )
        ) {
            try await repository.start([.init(rawValue: 1)])
        }
    }

    @Test("updateTransferSettings формирует корректные аргументы для torrent-set")
    func updateTransferSettingsArguments() async throws {
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        let capturedArguments = LockedValue<[String: AnyCodable]?>(nil)
        client.torrentSet = { ids, arguments in
            capturedIds.set(ids)
            if case .object(let dict) = arguments {
                capturedArguments.set(dict)
            } else {
                Issue.record("Ожидался объект аргументов")
            }
            return TransmissionResponse(result: "success")
        }

        let repository = TorrentRepository.live(transmissionClient: client)

        try await repository.updateTransferSettings(
            .init(
                downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 512),
                uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 1024)
            ),
            for: [.init(rawValue: 3)]
        )

        #expect(capturedIds.value == [3])
        let arguments = try #require(capturedArguments.value)
        #expect(arguments["downloadLimit"] == .int(512))
        #expect(arguments["downloadLimited"] == .bool(true))
        #expect(arguments["uploadLimit"] == .int(1024))
        #expect(arguments["uploadLimited"] == .bool(false))
    }

    @Test("updateFileSelection передаёт индексы wanted/priority")
    func updateFileSelectionArguments() async throws {
        var client = TransmissionClientDependency.placeholder
        let capturedIds = LockedValue<[Int]?>(nil)
        let capturedArguments = LockedValue<[String: AnyCodable]?>(nil)
        client.torrentSet = { ids, arguments in
            capturedIds.set(ids)
            if case .object(let dict) = arguments {
                capturedArguments.set(dict)
            } else {
                Issue.record("Ожидался объект аргументов")
            }
            return TransmissionResponse(result: "success")
        }

        let repository = TorrentRepository.live(transmissionClient: client)

        try await repository.updateFileSelection(
            [
                .init(fileIndex: 0, isWanted: true, priority: .high),
                .init(fileIndex: 1, isWanted: false, priority: .low),
                .init(fileIndex: 2, isWanted: nil, priority: .normal)
            ],
            in: .init(rawValue: 5)
        )

        #expect(capturedIds.value == [5])
        let arguments = try #require(capturedArguments.value)
        #expect(arguments["files-wanted"] == .array([.int(0)]))
        #expect(arguments["files-unwanted"] == .array([.int(1)]))
        #expect(arguments["priority-high"] == .array([.int(0)]))
        #expect(arguments["priority-low"] == .array([.int(1)]))
        #expect(arguments["priority-normal"] == .array([.int(2)]))
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ newValue: Value) {
        lock.lock()
        storage = newValue
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
