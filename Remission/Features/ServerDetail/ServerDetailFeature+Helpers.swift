import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func resetTorrentListOnReconnectIfNeeded(
        state: inout State
    ) -> Effect<Action> {
        guard state.torrentList.items.isEmpty == false else { return .none }
        switch state.connectionState.phase {
        case .ready:
            return .none
        case .idle, .connecting, .offline, .failed:
            state.torrentList.items.removeAll()
            state.torrentList.storageSummary = nil
            return .send(.torrentList(.resetForReconnect))
        }
    }

    func startConnectionIfNeeded(
        state: inout State
    ) -> Effect<Action> {
        let fingerprint = state.server.connectionFingerprint
        guard case .ready(let ready) = state.connectionState.phase,
            ready.fingerprint == fingerprint,
            state.connectionEnvironment?.isValid(for: state.server) == true
        else {
            return startConnection(state: &state, force: false)
        }
        return .none
    }

    func clearOfflineCache(serverID: UUID) -> Effect<Action> {
        .run { _ in
            do {
                try await offlineCacheRepository.clear(serverID)
            } catch {
                // Кеш опционален
            }
        }
    }

    func isIncompatibleVersion(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        if case .versionUnsupported = apiError {
            return true
        }
        return false
    }

    func loadPreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            await send(
                .userPreferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.preferences, cancelInFlight: true)
    }

    func observePreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe(serverID: serverID)
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: ConnectionCancellationID.preferencesUpdates, cancelInFlight: true)
    }

    func applyDefaultSpeedLimitsIfNeeded(
        state: inout State
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment,
            let preferences = state.preferences
        else {
            return .none
        }
        let limits = preferences.defaultSpeedLimits
        guard state.lastAppliedDefaultSpeedLimits != limits else {
            return .none
        }
        state.lastAppliedDefaultSpeedLimits = limits
        return applyDefaultSpeedLimits(
            limits: limits,
            environment: environment
        )
    }

    func applyDefaultSpeedLimits(
        limits: UserPreferences.DefaultSpeedLimits,
        environment: ServerConnectionEnvironment
    ) -> Effect<Action> {
        .run { _ in
            try await environment.withDependencies {
                @Dependency(\.sessionRepository) var sessionRepository
                let download = SessionState.SpeedLimits.Limit(
                    isEnabled: limits.downloadKilobytesPerSecond != nil,
                    kilobytesPerSecond: limits.downloadKilobytesPerSecond ?? 0
                )
                let upload = SessionState.SpeedLimits.Limit(
                    isEnabled: limits.uploadKilobytesPerSecond != nil,
                    kilobytesPerSecond: limits.uploadKilobytesPerSecond ?? 0
                )
                let update = SessionRepository.SessionUpdate(
                    speedLimits: .init(
                        download: download,
                        upload: upload,
                        alternative: nil
                    )
                )
                _ = try await sessionRepository.updateState(update)
            }
        }
        .cancellable(
            id: ConnectionCancellationID.defaultSpeedLimits,
            cancelInFlight: true
        )
    }

    var maxConnectionRetryAttempts: Int { 5 }
}
