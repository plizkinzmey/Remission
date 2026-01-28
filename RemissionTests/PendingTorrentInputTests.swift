import Foundation
import Testing

@testable import Remission

@Suite("Pending Torrent Input Tests")
struct PendingTorrentInputTests {
    // Проверяет displayName для .torrent файла с именем и без имени.
    @Test
    func displayNameForTorrentFile() {
        let withName = PendingTorrentInput(
            payload: .torrentFile(data: Data([0x00]), fileName: "ubuntu.torrent"),
            sourceDescription: "files"
        )
        #expect(withName.displayName == "ubuntu.torrent")
        #expect(withName.isMagnetLink == false)

        let withoutName = PendingTorrentInput(
            payload: .torrentFile(data: Data(), fileName: nil),
            sourceDescription: "files"
        )
        #expect(withoutName.displayName == "torrent")
    }

    // Проверяет displayName и флаг для magnet-ссылки.
    @Test
    func displayNameForMagnetLink() {
        let raw = "magnet:?xt=urn:btih:123"
        let input = PendingTorrentInput(
            payload: .magnetLink(url: URL(string: raw)!, rawValue: raw),
            sourceDescription: "clipboard"
        )

        #expect(input.displayName == raw)
        #expect(input.isMagnetLink)
    }
}
