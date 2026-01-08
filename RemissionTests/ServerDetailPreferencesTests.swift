import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerDetailPreferencesTests {
    @Test
    // swiftlint:disable:next function_body_length
    func preferencesUpdatePropagatesToTorrentList() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = makeHandshake()
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server, handshake: handshake)

        let preferencesBox = ServerDetailLockedValue(DomainFixtures.userPreferences)
        let continuationBox = ServerDetailPreferencesContinuationBox()
        let repository = makePreferencesRepository(
            preferencesBox: preferencesBox,
            continuationBox: continuationBox
        )

        var initialState = makeInitialState(
            server: server,
            environment: environment,
            handshake: handshake
        )

        let store = TestStore(initialState: initialState) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.task)

        let initial = preferencesBox.value
        await receiveInitialPreferences(initial, in: store)

        var updated = preferencesBox.value
        updated.pollingInterval = 30
        updated.isAutoRefreshEnabled = false
        preferencesBox.set(updated)
        await receiveUpdatedPreferences(updated, in: store)

        await continuationBox.finish()
        await store.finish()
    }
}

@MainActor
private func receiveInitialPreferences(
    _ preferences: UserPreferences,
    in store: TestStore<ServerDetailReducer.State, ServerDetailReducer.Action>
) async {
    await store.receive(.userPreferencesResponse(.success(preferences))) {
        $0.preferences = preferences
        $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
    }
    await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
        $0.torrentList.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
        $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
        $0.torrentList.phase = .loading
        $0.torrentList.hasLoadedPreferences = true
    }
    await store.receive(
        .torrentList(
            .torrentsResponse(
                .success(.init(torrents: [], isFromCache: false, snapshotDate: nil))
            )
        )
    ) {
        $0.torrentList.phase = .loaded
    }
}

@MainActor
private func receiveUpdatedPreferences(
    _ preferences: UserPreferences,
    in store: TestStore<ServerDetailReducer.State, ServerDetailReducer.Action>
) async {
    await store.send(.userPreferencesResponse(.success(preferences))) {
        $0.preferences = preferences
        $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
    }
    await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
        $0.torrentList.pollingInterval = .seconds(Int(preferences.pollingInterval))
        $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
        $0.torrentList.hasLoadedPreferences = true
    }
    await store.receive(
        .torrentList(
            .torrentsResponse(
                .success(.init(torrents: [], isFromCache: false, snapshotDate: nil))
            )
        )
    )
}

private func makeHandshake() -> TransmissionHandshakeResult {
    TransmissionHandshakeResult(
        sessionID: "observer",
        rpcVersion: 20,
        minimumSupportedRpcVersion: 14,
        serverVersionDescription: "Transmission 4.0.3",
        isCompatible: true
    )
}

private func makePreferencesRepository(
    preferencesBox: ServerDetailLockedValue<UserPreferences>,
    continuationBox: ServerDetailPreferencesContinuationBox
) -> UserPreferencesRepository {
    UserPreferencesRepository(
        load: { _ in preferencesBox.value },
        updatePollingInterval: { _, interval in
            var updated = preferencesBox.value
            updated.pollingInterval = interval
            preferencesBox.set(updated)
            return updated
        },
        setAutoRefreshEnabled: { _, isEnabled in
            var updated = preferencesBox.value
            updated.isAutoRefreshEnabled = isEnabled
            preferencesBox.set(updated)
            return updated
        },
        setTelemetryEnabled: { _, isEnabled in
            var updated = preferencesBox.value
            updated.isTelemetryEnabled = isEnabled
            preferencesBox.set(updated)
            return updated
        },
        updateDefaultSpeedLimits: { _, limits in
            var updated = preferencesBox.value
            updated.defaultSpeedLimits = limits
            preferencesBox.set(updated)
            return updated
        },
        observe: { _ in
            AsyncStream { continuation in
                Task {
                    await continuationBox.set(continuation)
                }
            }
        }
    )
}

private func makeInitialState(
    server: ServerConfig,
    environment: ServerConnectionEnvironment,
    handshake: TransmissionHandshakeResult
) -> ServerDetailReducer.State {
    var state = ServerDetailReducer.State(server: server)
    state.connectionEnvironment = environment
    state.connectionState.phase = .ready(
        .init(fingerprint: environment.fingerprint, handshake: handshake))
    state.torrentList.connectionEnvironment = environment
    return state
}
