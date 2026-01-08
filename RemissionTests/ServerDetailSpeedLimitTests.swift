import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length
@MainActor
struct ServerDetailSpeedLimitTests {
    @Test
    func appliesDefaultSpeedLimitsOnConnect() async {
        let server = ServerConfig.previewLocalHTTP
        let limits = UserPreferences.DefaultSpeedLimits(
            downloadKilobytesPerSecond: 1200,
            uploadKilobytesPerSecond: nil
        )
        let preferences = UserPreferences(
            pollingInterval: 5,
            isAutoRefreshEnabled: true,
            isTelemetryEnabled: false,
            defaultSpeedLimits: limits
        )

        let updates = ServerDetailLockedValue<[SessionRepository.SessionUpdate]>([])
        let sessionRepository = SessionRepository(
            performHandshake: {
                .init(
                    sessionID: nil,
                    rpcVersion: 0,
                    minimumSupportedRpcVersion: 0,
                    serverVersionDescription: nil,
                    isCompatible: true
                )
            },
            fetchState: { .previewActive },
            updateState: { update in
                updates.withValue { $0.append(update) }
                return .previewActive
            },
            checkCompatibility: { .init(isCompatible: true, rpcVersion: 20) }
        )

        var initialState = ServerDetailReducer.State(server: server)
        initialState.connectionEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            sessionRepository: sessionRepository
        )
        initialState.connectionState.phase = .ready(
            .init(
                fingerprint: initialState.connectionEnvironment!.fingerprint,
                handshake: .init(
                    sessionID: "session-limits",
                    rpcVersion: 20,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission 4.0.3",
                    isCompatible: true
                )
            )
        )
        initialState.torrentList.connectionEnvironment = initialState.connectionEnvironment

        let store = TestStore(initialState: initialState) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.userPreferencesRepository = .serverDetailTestValue(
                preferences: preferences
            )
        }
        store.exhaustivity = .off

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.preferences = preferences
            $0.lastAppliedDefaultSpeedLimits = limits
        }

        #expect(updates.value.count == 1)
        let update = updates.value.first?.speedLimits
        #expect(update?.download == .init(isEnabled: true, kilobytesPerSecond: 1200))
        #expect(update?.upload == .init(isEnabled: false, kilobytesPerSecond: 0))
    }

    @Test
    func replaysDefaultSpeedLimitsWhenPreferencesChange() async {
        let server = ServerConfig.previewLocalHTTP
        let initialPreferences = UserPreferences(
            pollingInterval: 5,
            isAutoRefreshEnabled: true,
            isTelemetryEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: nil,
                uploadKilobytesPerSecond: nil
            )
        )

        let updatedPreferences = UserPreferences(
            pollingInterval: 5,
            isAutoRefreshEnabled: true,
            isTelemetryEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: 2048,
                uploadKilobytesPerSecond: 512
            )
        )

        let preferencesBox = ServerDetailLockedValue(initialPreferences)
        let continuationBox = ServerDetailPreferencesContinuationBox()

        let repository = UserPreferencesRepository(
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
                AsyncStream { cont in
                    Task { await continuationBox.set(cont) }
                }
            }
        )

        let updates = ServerDetailLockedValue<[SessionRepository.SessionUpdate]>([])
        let sessionRepository = SessionRepository(
            performHandshake: {
                .init(
                    sessionID: nil,
                    rpcVersion: 0,
                    minimumSupportedRpcVersion: 0,
                    serverVersionDescription: nil,
                    isCompatible: true
                )
            },
            fetchState: { .previewActive },
            updateState: { update in
                updates.withValue { $0.append(update) }
                return .previewActive
            },
            checkCompatibility: { .init(isCompatible: true, rpcVersion: 20) }
        )

        var initialState = ServerDetailReducer.State(server: server)
        initialState.connectionEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            sessionRepository: sessionRepository
        )
        initialState.connectionState.phase = .ready(
            .init(
                fingerprint: initialState.connectionEnvironment!.fingerprint,
                handshake: .init(
                    sessionID: "session-limits-updated",
                    rpcVersion: 20,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission 4.0.3",
                    isCompatible: true
                )
            )
        )
        initialState.torrentList.connectionEnvironment = initialState.connectionEnvironment

        let store = TestStore(initialState: initialState) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.userPreferencesResponse(.success(initialPreferences))) {
            $0.preferences = initialPreferences
            $0.lastAppliedDefaultSpeedLimits = initialPreferences.defaultSpeedLimits
        }

        #expect(updates.value.count == 1)
        #expect(
            updates.value.first?.speedLimits?.download
                == .init(isEnabled: false, kilobytesPerSecond: 0)
        )
        #expect(
            updates.value.first?.speedLimits?.upload
                == .init(isEnabled: false, kilobytesPerSecond: 0)
        )

        preferencesBox.set(updatedPreferences)
        await store.send(.userPreferencesResponse(.success(updatedPreferences))) {
            $0.preferences = updatedPreferences
            $0.lastAppliedDefaultSpeedLimits = updatedPreferences.defaultSpeedLimits
        }

        #expect(updates.value.count == 2)
        let last = updates.value.last?.speedLimits
        #expect(
            last?.download == .init(isEnabled: true, kilobytesPerSecond: 2048)
        )
        #expect(
            last?.upload == .init(isEnabled: true, kilobytesPerSecond: 512)
        )
    }
}
// swiftlint:enable function_body_length
