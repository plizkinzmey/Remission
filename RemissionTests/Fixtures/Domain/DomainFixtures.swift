import Foundation

@testable import Remission

enum DomainFixtures {
    // MARK: - Torrent

    static let torrentDownloading: Torrent = {
        var torrent = Torrent.previewDownloading
        torrent.id = .init(rawValue: 10)
        return torrent
    }()

    static let torrentCompleted: Torrent = {
        var torrent = Torrent.previewCompleted
        torrent.id = .init(rawValue: 11)
        return torrent
    }()

    static let torrents: [Torrent] = [
        torrentDownloading,
        torrentCompleted
    ]

    static func makeTorrentStore(
        torrents: [Torrent] = DomainFixtures.torrents
    ) -> InMemoryTorrentRepositoryStore {
        InMemoryTorrentRepositoryStore(torrents: torrents)
    }

    // MARK: - Session

    static let sessionHandshake: SessionRepository.Handshake = .init(
        sessionID: "fixture-session",
        rpcVersion: 17,
        minimumSupportedRpcVersion: 14,
        serverVersionDescription: "Transmission 4.0.4",
        isCompatible: true
    )

    static let sessionCompatibility: SessionRepository.Compatibility = .init(
        isCompatible: true,
        rpcVersion: 17
    )

    static let sessionState: SessionState = {
        var state = SessionState.previewActive
        state.rpc = .init(
            rpcVersion: 17,
            rpcVersionMinimum: 14,
            serverVersion: "Transmission 4.0.4"
        )
        return state
    }()

    static func makeSessionStore(
        handshake: SessionRepository.Handshake = DomainFixtures.sessionHandshake,
        state: SessionState = DomainFixtures.sessionState,
        compatibility: SessionRepository.Compatibility = DomainFixtures.sessionCompatibility
    ) -> InMemorySessionRepositoryStore {
        InMemorySessionRepositoryStore(
            handshake: handshake,
            state: state,
            compatibility: compatibility
        )
    }

    // MARK: - User Preferences

    static let userPreferences: UserPreferences = {
        var preferences: UserPreferences = .default
        preferences.pollingInterval = 3
        preferences.isAutoRefreshEnabled = true
        preferences.defaultSpeedLimits = .init(
            downloadKilobytesPerSecond: 2_048,
            uploadKilobytesPerSecond: 1_024
        )
        return preferences
    }()

    static func makeUserPreferencesStore(
        preferences: UserPreferences = DomainFixtures.userPreferences
    ) -> InMemoryUserPreferencesRepositoryStore {
        InMemoryUserPreferencesRepositoryStore(preferences: preferences)
    }
}
