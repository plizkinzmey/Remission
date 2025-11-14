import Foundation

@testable import Remission

/// Утилиты для загрузки доменных торрентов из Transmission-фикстур.
enum TorrentFixture {
    /// Возвращает список торрентов для UI/интеграционных тестов.
    /// Источник — `Transmission/Torrents/torrent-list-sample.json`.
    static let torrentListSample: [Torrent] = {
        do {
            let response = try TransmissionFixture.response(.torrentListSample)
            return try TransmissionDomainMapper().mapTorrentList(from: response)
        } catch {
            assertionFailure("Failed to load torrent-list-sample fixture: \(error)")
            return []
        }
    }()
}
