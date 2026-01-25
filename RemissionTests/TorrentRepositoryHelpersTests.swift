import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Helpers")
struct TorrentRepositoryHelpersTests {
    @Test("ensureSuccess пропускает success и бросает rpcError на ошибке")
    func ensureSuccessValidatesRPCResult() {
        // Этот тест защищает центральную точку проверки Transmission RPC-ответов.
        // Если убрать/сломать эту проверку, мы начнём маппить ошибки как успех.
        let success = TransmissionResponse(result: "success")
        do {
            try TorrentRepository.ensureSuccess(success, context: "torrent-start")
        } catch {
            Issue.record("Не ожидали ошибку на success-ответе: \(error)")
        }

        let failure = TransmissionResponse(result: "permission denied")

        do {
            try TorrentRepository.ensureSuccess(failure, context: "torrent-start")
            Issue.record("Ожидали DomainMappingError.rpcError, но ошибка не была брошена")
        } catch let error as DomainMappingError {
            #expect(error == .rpcError(result: "permission denied", context: "torrent-start"))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }

    @Test("makeTransferSettingsArguments формирует аргументы только для заданных лимитов")
    func makeTransferSettingsArgumentsRespectsOptionalLimits() {
        // Мы проверяем, что nil-лимиты не попадают в RPC-аргументы,
        // а заданные лимиты раскладываются в правильные ключи.
        let download = TorrentRepository.TransferLimit(isEnabled: true, kilobytesPerSecond: 512)
        let upload = TorrentRepository.TransferLimit(isEnabled: false, kilobytesPerSecond: 128)
        let settings = TorrentRepository.TransferSettings(
            downloadLimit: download, uploadLimit: upload)

        let arguments = TorrentRepository.makeTransferSettingsArguments(from: settings)

        #expect(arguments["downloadLimit"] == .int(512))
        #expect(arguments["downloadLimited"] == .bool(true))
        #expect(arguments["uploadLimit"] == .int(128))
        #expect(arguments["uploadLimited"] == .bool(false))

        // Пустые настройки должны давать полностью пустой словарь.
        let empty = TorrentRepository.makeTransferSettingsArguments(from: .init())
        #expect(empty.isEmpty)
    }

    @Test("makeFileSelectionArguments агрегирует wanted и приоритеты по индексам")
    func makeFileSelectionArgumentsAggregatesWantedAndPriorities() {
        // Этот тест покрывает логику агрегации и сортировки:
        // - wanted/unwanted должны быть уникальными и отсортированными
        // - приоритеты должны раскладываться по своим bucket'ам
        let updates: [TorrentRepository.FileSelectionUpdate] = [
            .init(fileIndex: 2, isWanted: true, priority: .normal),
            .init(fileIndex: 0, isWanted: true, priority: .high),
            .init(fileIndex: 1, isWanted: false, priority: .low),
            // Дубликат не должен ломать результат.
            .init(fileIndex: 1, isWanted: false, priority: .low)
        ]

        let arguments = TorrentRepository.makeFileSelectionArguments(from: updates)

        #expect(arguments["files-wanted"] == .array([.int(0), .int(2)]))
        #expect(arguments["files-unwanted"] == .array([.int(1)]))
        #expect(arguments["priority-high"] == .array([.int(0)]))
        #expect(arguments["priority-normal"] == .array([.int(2)]))
        #expect(arguments["priority-low"] == .array([.int(1)]))
    }

    @Test("PendingTorrentInput корректно раскладывается в filename и metainfo аргументы")
    func pendingTorrentInputArgumentsMatchPayloadType() throws {
        // Это важный контракт для torrent-add: magnet уходит в filename,
        // а .torrent-файл — в metainfo.
        let magnetURL = try #require(URL(string: "magnet:?xt=urn:btih:123"))
        let magnet = PendingTorrentInput(
            payload: .magnetLink(url: magnetURL, rawValue: magnetURL.absoluteString),
            sourceDescription: "test"
        )

        #expect(magnet.filenameArgument == magnetURL.absoluteString)
        #expect(magnet.metainfoArgument == nil)

        let fileData = Data([0x01, 0x02, 0x03])
        let torrentFile = PendingTorrentInput(
            payload: .torrentFile(data: fileData, fileName: "file.torrent"),
            sourceDescription: "test"
        )

        #expect(torrentFile.filenameArgument == nil)
        #expect(torrentFile.metainfoArgument == fileData)
    }
}
