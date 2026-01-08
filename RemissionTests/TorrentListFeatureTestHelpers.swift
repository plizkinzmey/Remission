import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// MARK: - Helpers

@MainActor
func makeStore(
    clock: TestClock<Duration>,
    repository: TorrentRepository,
    preferences: UserPreferences
) -> TestStoreOf<TorrentListReducer> {
    let server = ServerConfig.previewLocalHTTP
    let environment = ServerConnectionEnvironment.testEnvironment(
        server: server,
        torrentRepository: repository
    )

    return TestStoreFactory.make(
        initialState: {
            var state = TorrentListReducer.State()
            state.connectionEnvironment = environment
            state.serverID = server.id
            return state
        }(),
        reducer: { TorrentListReducer() },
        configure: { dependencies in
            dependencies.appClock = .test(clock: clock)
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
            dependencies.offlineCacheRepository = .inMemory()
        }
    )
}

func makeLoadedState(torrents: [Torrent]) -> TorrentListReducer.State {
    var state = TorrentListReducer.State()
    state.connectionEnvironment = .preview(server: .previewLocalHTTP)
    state.serverID = ServerConfig.previewLocalHTTP.id
    state.phase = .loaded
    state.items = IdentifiedArray(
        uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
    )
    return state
}

func makeFetchSuccess(
    _ torrents: [Torrent],
    isFromCache: Bool = false,
    snapshotDate: Date? = nil
) -> TorrentListReducer.State.FetchSuccess {
    TorrentListReducer.State.FetchSuccess(
        torrents: torrents,
        isFromCache: isFromCache,
        snapshotDate: snapshotDate
    )
}

final class TorrentListRecordingClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = TestClock<Duration>.Instant

    private let base: TestClock<Duration>
    private(set) var sleepHistory: [Duration] = []

    init(base: TestClock<Duration>) {
        self.base = base
    }

    var now: Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let interval = base.now.duration(to: deadline)
        sleepHistory.append(interval)
        try await base.sleep(until: deadline, tolerance: tolerance)
    }

    func sleep(for duration: Duration, tolerance: Duration? = nil) async throws {
        sleepHistory.append(duration)
        try await base.sleep(for: duration, tolerance: tolerance)
    }
}

extension UserPreferencesRepository {
    static func testValue(preferences: UserPreferences) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { _ in preferences },
            updatePollingInterval: { _, _ in preferences },
            setAutoRefreshEnabled: { _, _ in preferences },
            setTelemetryEnabled: { _, _ in preferences },
            updateDefaultSpeedLimits: { _, _ in preferences },
            observe: { _ in
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }

    static func failingLoad(error: any Error) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { _ in throw error },
            updatePollingInterval: { _, interval in
                var prefs = DomainFixtures.userPreferences
                prefs.pollingInterval = interval
                return prefs
            },
            setAutoRefreshEnabled: { _, isEnabled in
                var prefs = DomainFixtures.userPreferences
                prefs.isAutoRefreshEnabled = isEnabled
                return prefs
            },
            setTelemetryEnabled: { _, isEnabled in
                var prefs = DomainFixtures.userPreferences
                prefs.isTelemetryEnabled = isEnabled
                return prefs
            },
            updateDefaultSpeedLimits: { _, limits in
                var prefs = DomainFixtures.userPreferences
                prefs.defaultSpeedLimits = limits
                return prefs
            },
            observe: { _ in
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }
}
