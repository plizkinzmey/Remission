import Foundation
import Testing

@testable import Remission

@Suite("InMemoryTorrentRepository")
struct InMemoryTorrentRepositoryTests {
    @Test("основные команды add/start/stop/verify/remove изменяют состояние торрентов")
    func commandFlowMutatesTorrentState() async throws {
        // Этот тест покрывает основной happy-path управления торрентами.
        let baseTorrent = makeTorrentWithDetails(id: 1, name: "Base")
        let store = InMemoryTorrentRepositoryStore(torrents: [baseTorrent])
        let repository = TorrentRepository.inMemory(store: store)

        let magnetURL = try #require(URL(string: "magnet:?xt=urn:btih:123"))
        let input = PendingTorrentInput(
            payload: .magnetLink(url: magnetURL, rawValue: magnetURL.absoluteString),
            sourceDescription: "test"
        )

        let addResult = try await repository.add(
            input, destinationPath: "/downloads", startPaused: true, tags: ["linux"])
        #expect(addResult.status == .added)

        var torrents = try await repository.fetchList()
        #expect(torrents.count == 2)

        try await repository.start([addResult.id])
        torrents = try await repository.fetchList()
        #expect(torrents.first(where: { $0.id == addResult.id })?.status == .downloading)

        try await repository.stop([addResult.id])
        torrents = try await repository.fetchList()
        #expect(torrents.first(where: { $0.id == addResult.id })?.status == .stopped)

        try await repository.verify([addResult.id])
        torrents = try await repository.fetchList()
        #expect(torrents.first(where: { $0.id == addResult.id })?.status == .checking)

        try await repository.remove([addResult.id], deleteLocalData: true)
        torrents = try await repository.fetchList()
        #expect(torrents.contains(where: { $0.id == addResult.id }) == false)
    }

    @Test("updateTransferSettings и updateFileSelection применяют изменения к деталям")
    func updatesMutateTransferLimitsAndFiles() async throws {
        // Покрываем два «мутационных» API, которые легко сломать при рефакторинге.
        let torrent = makeTorrentWithDetails(id: 7, name: "Ubuntu")
        let store = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: store)

        let settings = TorrentRepository.TransferSettings(
            downloadLimit: .init(isEnabled: true, kilobytesPerSecond: 512),
            uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 128)
        )
        try await repository.updateTransferSettings(settings, for: [torrent.id])

        try await repository.updateFileSelection(
            [
                .init(fileIndex: 0, isWanted: false, priority: .high),
                // Некорректный индекс должен быть безопасно проигнорирован.
                .init(fileIndex: 99, isWanted: true, priority: .low)
            ],
            in: torrent.id
        )

        let updated = try await repository.fetchDetails(torrent.id)
        #expect(updated.summary.transfer.downloadLimit.kilobytesPerSecond == 512)
        #expect(updated.summary.transfer.downloadLimit.isEnabled)
        #expect(updated.summary.transfer.uploadLimit.kilobytesPerSecond == 128)

        let file = try #require(updated.details?.files.first)
        #expect(file.wanted == false)
        #expect(file.priority == TorrentRepository.FilePriority.high.rawValue)
    }

    @Test("fetchList бросает operationFailed, когда операция помечена как failing")
    func fetchListFailureIsPropagated() async {
        // Error-path обязателен для проверки UI-веток ошибок.
        let store = InMemoryTorrentRepositoryStore(torrents: [])
        let repository = TorrentRepository.inMemory(store: store)

        await store.markFailure(.fetchList)

        do {
            _ = try await repository.fetchList()
            Issue.record("Ожидали ошибку fetchList, но она не была брошена")
        } catch let error as InMemoryTorrentRepositoryError {
            switch error {
            case .operationFailed(let operation):
                #expect(operation == .fetchList)
            default:
                Issue.record("Ожидали operationFailed(.fetchList), получили: \(error)")
            }
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}

private func makeTorrentWithDetails(id: Int, name: String) -> Torrent {
    var torrent = Torrent.previewDownloading
    torrent.id = .init(rawValue: id)
    torrent.name = name
    torrent.details = Torrent.Details(
        downloadDirectory: "/downloads",
        addedDate: Date(timeIntervalSince1970: 0),
        files: [
            .init(
                index: 0, name: "file.bin", length: 100, bytesCompleted: 10, priority: 0,
                wanted: true)
        ],
        trackers: [],
        trackerStats: [],
        speedSamples: []
    )
    return torrent
}
