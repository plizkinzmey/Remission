import Foundation
import Testing

@testable import Remission

@Suite("TorrentDetailModels")
struct TorrentDetailModelsTests {
    @Test("Torrent.File.progress возвращает долю completed/length и 0 при нулевой длине")
    func fileProgressCalculatesSafeRatio() {
        // Этот тест фиксирует защиту от деления на ноль и корректную долю прогресса.
        let completed = Torrent.File(
            index: 0,
            name: "file.bin",
            length: 200,
            bytesCompleted: 50,
            priority: 0,
            wanted: true
        )
        #expect(completed.progress == 0.25)

        let empty = Torrent.File(
            index: 1,
            name: "empty.bin",
            length: 0,
            bytesCompleted: 0,
            priority: 0,
            wanted: true
        )
        #expect(empty.progress == 0.0)
    }

    @Test("Torrent.Tracker.displayName использует host, а при невалидном URL — исходную строку")
    func trackerDisplayNamePrefersHost() {
        // UI ожидает короткое и понятное имя трекера.
        let valid = Torrent.Tracker(
            id: 1, announce: "https://tracker.example.com/announce", tier: 0)
        #expect(valid.displayName == "tracker.example.com")

        let invalid = Torrent.Tracker(id: 2, announce: "not a url", tier: 0)
        #expect(invalid.displayName == "not a url")
    }
}
