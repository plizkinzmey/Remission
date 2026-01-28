import SwiftUI
import Testing

@testable import Remission

@Suite("Torrent Action Type Tests")
struct TorrentActionTypeTests {
    // Проверяет стабильность количества действий и rawValue-названий.
    @Test
    func allCasesAndRawValuesAreStable() {
        #expect(TorrentActionType.allCases == [.start, .pause, .verify, .remove])
        #expect(TorrentActionType.start.rawValue == "start")
        #expect(TorrentActionType.pause.rawValue == "pause")
        #expect(TorrentActionType.verify.rawValue == "verify")
        #expect(TorrentActionType.remove.rawValue == "remove")
    }

    // Проверяет контракт системных иконок и accessibilityIdentifier.
    @Test
    func systemImagesAndAccessibilityIdentifiersMatchContract() {
        #expect(TorrentActionType.start.systemImage == "play.fill")
        #expect(TorrentActionType.pause.systemImage == "pause.fill")
        #expect(TorrentActionType.verify.systemImage == "checkmark.shield.fill")
        #expect(TorrentActionType.remove.systemImage == "trash.fill")

        for action in TorrentActionType.allCases {
            #expect(action.accessibilityIdentifier == "torrent-action-\(action.rawValue)")
            #expect(action.title.isEmpty == false)
        }
    }
}
