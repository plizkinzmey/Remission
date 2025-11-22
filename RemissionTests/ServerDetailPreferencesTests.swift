import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerDetailPreferencesTests {
    @Test
    func preferencesUpdatePropagatesToTorrentList() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "observer",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake
        )

        let preferencesBox = ServerDetailLockedValue(DomainFixtures.userPreferences)
        let continuationBox = ServerDetailPreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferencesBox.value },
            updatePollingInterval: { interval in
                var updated = preferencesBox.value
                updated.pollingInterval = interval
                preferencesBox.set(updated)
                return updated
            },
            setAutoRefreshEnabled: { isEnabled in
                var updated = preferencesBox.value
                updated.isAutoRefreshEnabled = isEnabled
                preferencesBox.set(updated)
                return updated
            },
            updateDefaultSpeedLimits: { limits in
                var updated = preferencesBox.value
                updated.defaultSpeedLimits = limits
                preferencesBox.set(updated)
                return updated
            },
            observe: {
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        var initialState = ServerDetailReducer.State(server: server)
        initialState.connectionEnvironment = environment
        initialState.connectionState.phase = .ready(
            .init(fingerprint: environment.fingerprint, handshake: handshake)
        )
        initialState.torrentList.connectionEnvironment = environment

        let store = TestStore(initialState: initialState) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.task)

        // Simulate initial preferences delivery
        let initial = preferencesBox.value
        await store.send(.userPreferencesResponse(.success(initial))) {
            $0.preferences = initial
            $0.lastAppliedDefaultSpeedLimits = initial.defaultSpeedLimits
        }
        await store.send(.torrentList(.userPreferencesResponse(.success(initial)))) {
            $0.torrentList.pollingInterval = .milliseconds(Int(initial.pollingInterval * 1_000))
            $0.torrentList.isPollingEnabled = initial.isAutoRefreshEnabled
        }

        // Simulate update
        var updated = preferencesBox.value
        updated.pollingInterval = 30
        updated.isAutoRefreshEnabled = false
        preferencesBox.set(updated)
        await store.send(.userPreferencesResponse(.success(updated))) {
            $0.preferences = updated
            $0.lastAppliedDefaultSpeedLimits = updated.defaultSpeedLimits
        }
        await store.send(.torrentList(.userPreferencesResponse(.success(updated)))) {
            $0.torrentList.pollingInterval = .seconds(30)
            $0.torrentList.isPollingEnabled = false
        }

        await continuationBox.finish()
        await store.finish()
    }
}
