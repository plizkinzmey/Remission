import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    // swiftlint:disable:next function_body_length
    func connectionReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            let serverID = state.server.id
            let resetEffect = resetTorrentListOnReconnectIfNeeded(state: &state)
            return .merge(
                startConnectionIfNeeded(state: &state),
                resetEffect,
                loadPreferences(serverID: serverID),
                observePreferences(serverID: serverID)
            )

        case .retryConnectionButtonTapped:
            state.errorPresenter.banner = nil
            return startConnection(state: &state, force: true)

        case .cacheKeyPrepared(let key):
            let changed = state.torrentList.cacheKey != key
            state.torrentList.cacheKey = key
            return changed ? .send(.torrentList(.restoreCachedSnapshot)) : .none

        case .connectionResponse(.success(let response)):
            let environment = response.environment.updatingRPCVersion(
                response.handshake.rpcVersion
            )
            state.connectionEnvironment = environment
            state.torrentDetail?.applyConnectionEnvironment(environment)
            state.addTorrent?.connectionEnvironment = environment
            state.connectionRetryAttempts = 0
            state.connectionState.phase = .ready(
                .init(
                    fingerprint: environment.fingerprint,
                    handshake: response.handshake
                )
            )
            state.torrentList.connectionEnvironment = environment
            state.torrentList.cacheKey = environment.cacheKey
            state.torrentList.handshake = response.handshake
            let effects: Effect<Action> = .concatenate(
                .send(.torrentList(.task)),
                .send(.torrentList(.refreshRequested))
            )
            return .merge(
                .cancel(id: ConnectionCancellationID.connectionRetry),
                effects,
                applyDefaultSpeedLimitsIfNeeded(state: &state)
            )

        case .connectionResponse(.failure(let error)):
            state.connectionEnvironment = nil
            state.lastAppliedDefaultSpeedLimits = nil
            state.torrentDetail?.applyConnectionEnvironment(nil)
            state.addTorrent?.connectionEnvironment = nil
            state.torrentList.connectionEnvironment = nil
            state.torrentList.handshake = nil
            state.torrentList.items.removeAll()
            state.torrentList.storageSummary = nil
            let message = error.userFacingMessage
            state.connectionRetryAttempts += 1
            state.connectionState.phase = .offline(
                .init(
                    message: message,
                    attempt: state.connectionRetryAttempts
                )
            )
            state.errorPresenter.banner = .init(
                message: message,
                retry: .reconnect
            )
            let teardown: Effect<Action> = .send(.torrentList(.teardown))
            let reset: Effect<Action> = .send(.torrentList(.resetForReconnect))
            let offlineEffect: Effect<Action> = .send(
                .torrentList(.goOffline(message: message))
            )
            let cacheClear: Effect<Action> =
                isIncompatibleVersion(error)
                ? clearOfflineCache(serverID: state.server.id)
                : .none
            return .merge(
                teardown,
                reset,
                offlineEffect,
                cacheClear,
                scheduleConnectionRetry(state: &state)
            )

        case .userPreferencesResponse(.success(let preferences)):
            state.preferences = preferences
            return applyDefaultSpeedLimitsIfNeeded(state: &state)

        case .userPreferencesResponse(.failure):
            return .none

        case .errorPresenter(.retryRequested(.reconnect)):
            return .send(.retryConnectionButtonTapped)

        case .errorPresenter:
            return .none

        default:
            return .none
        }
    }
}
