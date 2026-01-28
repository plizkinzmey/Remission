import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("TorrentFileLoaderDependency Tests")
struct TorrentFileLoaderDependencyTests {
    // Проверяет, что liveValue действительно читает байты из файла по URL.
    @Test
    func liveValueLoadsDataFromFileURL() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("torrent")
        let expected = Data([0x74, 0x65, 0x73, 0x74])

        try expected.write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let loader = TorrentFileLoaderDependency.liveValue
        let loaded = try loader.load(url)

        #expect(loaded == expected)
    }

    // Проверяет, что testValue ведёт себя как безопасный stub и возвращает пустые данные.
    @Test
    func testValueReturnsEmptyData() throws {
        let url = URL(fileURLWithPath: "/does/not/matter.torrent")
        let loader = TorrentFileLoaderDependency.testValue

        let loaded = try loader.load(url)

        #expect(loaded.isEmpty)
    }
}
