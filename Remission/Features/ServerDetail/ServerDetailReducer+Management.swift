import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func managementReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .editButtonTapped:
            state.editor = ServerFormReducer.State(mode: .edit(state.server))
            return .none

        case .deleteButtonTapped:
            state.alert = AlertFactory.deleteConfirmation(
                title: L10n.tr("serverDetail.alert.delete.title"),
                message: L10n.tr("serverDetail.alert.delete.message"),
                confirmAction: .confirmDeletion,
                cancelAction: .cancelDeletion
            )
            return .none

        case .deleteCompleted(.success):
            state.isDeleting = false
            return .merge(
                .cancel(id: ConnectionCancellationID.connection),
                .send(.delegate(.serverDeleted(state.server.id)))
            )

        case .deleteCompleted(.failure(let error)):
            state.isDeleting = false
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.delete.title"),
                message: error.message,
                action: .dismiss
            )
            return .none

        case .httpWarningResetButtonTapped:
            httpWarningPreferencesStore.reset(state.server.httpWarningFingerprint)
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.httpWarningsReset.title"),
                message: L10n.tr("serverDetail.alert.httpWarningsReset.message"),
                buttonText: L10n.tr("serverDetail.alert.httpWarningsReset.button"),
                action: .dismiss
            )
            return .none

        case .resetTrustButtonTapped:
            state.alert = AlertFactory.confirmation(
                title: L10n.tr("serverDetail.alert.trustReset.title"),
                message: L10n.tr("serverDetail.alert.trustReset.message"),
                confirmText: L10n.tr("serverDetail.alert.trustReset.confirm"),
                confirmAction: .confirmReset,
                cancelAction: .cancelReset
            )
            return .none

        case .resetTrustSucceeded:
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.trustResetDone.title"),
                message: L10n.tr("serverDetail.alert.trustResetDone.message"),
                buttonText: L10n.tr("serverDetail.alert.trustResetDone.button"),
                action: .dismiss
            )
            return .none

        case .resetTrustFailed(let message):
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.trustResetFailed.title"),
                message: message,
                action: .dismiss
            )
            return .none

        case .alert(.presented(.confirmDeletion)):
            state.alert = nil
            state.isDeleting = true
            return deleteServer(state.server)

        case .alert(.presented(.confirmReset)):
            state.alert = nil
            return performTrustReset(for: state.server)

        case .alert(.presented(.cancelReset)), .alert(.presented(.cancelDeletion)):
            state.alert = nil
            return .none

        case .alert(.presented(.dismiss)):
            state.alert = nil
            return .none

        case .alert(.dismiss):
            return .none

        case .editor(.presented(.delegate(.didUpdate(let server)))):
            let shouldReconnect =
                state.server.connectionFingerprint != server.connectionFingerprint
            state.server = server
            state.torrentList.serverID = server.id
            let teardownEffect: Effect<Action> =
                shouldReconnect ? .send(.torrentList(.teardown)) : .none
            if shouldReconnect {
                state.torrentList = .init()
                state.torrentList.serverID = server.id
                state.connectionEnvironment = nil
                state.lastAppliedDefaultSpeedLimits = nil
            }
            let connectionEffect =
                shouldReconnect
                ? startConnection(state: &state, force: true) : .none
            return .concatenate(
                teardownEffect,
                .send(.delegate(.serverUpdated(server))),
                connectionEffect,
                .send(.editor(.dismiss))
            )

        case .editor(.presented(.delegate(.cancelled))):
            return .send(.editor(.dismiss))

        case .editor:
            return .none

        default:
            return .none
        }
    }
}
