import ComposableArchitecture
import Foundation

extension ServerListReducer {
    func managementReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            state.hasPresentedInitialOnboarding = true
            state.serverForm = ServerFormReducer.State(mode: .add)
            return .none

        case .serverTapped(let id):
            guard let server = state.servers[id: id] else {
                return .none
            }
            return .send(.delegate(.serverSelected(server)))

        case .editButtonTapped(let id):
            guard let server = state.servers[id: id] else {
                return .none
            }
            state.serverForm = ServerFormReducer.State(mode: .edit(server))
            return .none

        case .deleteButtonTapped(let id):
            guard let server = state.servers[id: id] else { return .none }
            state.pendingDeletion = server
            state.deleteConfirmation = AlertFactory.confirmationDialog(
                title: String(format: L10n.tr("serverList.alert.delete.title"), server.name),
                message: L10n.tr("serverList.alert.delete.message"),
                confirmAction: .confirm,
                cancelAction: .cancel
            )
            return .none

        case .alert(.presented(.dismiss)):
            state.alert = nil
            return .none

        case .alert:
            return .none

        case .deleteConfirmation(.presented(.confirm)):
            guard let server = state.pendingDeletion else {
                state.deleteConfirmation = nil
                return .none
            }
            state.pendingDeletion = nil
            state.deleteConfirmation = nil
            return deleteServer(server)

        case .deleteConfirmation(.presented(.cancel)):
            state.pendingDeletion = nil
            state.deleteConfirmation = nil
            return .none

        case .deleteConfirmation:
            return .none

        case .serverForm(.presented(.delegate(.didCreate(let server)))):
            state.servers.append(server)
            state.serverForm = nil
            return .merge(
                .send(.delegate(.serverCreated(server))),
                .send(.connectionProbeRequested(server.id))
            )

        case .serverForm(.presented(.delegate(.didUpdate(let server)))):
            state.servers[id: server.id] = server
            state.serverForm = nil
            return .send(.connectionProbeRequested(server.id))

        case .serverForm(.presented(.delegate(.cancelled))):
            state.serverForm = nil
            return .none

        case .serverForm(.dismiss):
            state.serverForm = nil
            return .none

        case .serverForm:
            return .none

        default:
            return .none
        }
    }

    private func deleteServer(_ server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                if let key = server.credentialsKey {
                    try await credentialsRepository.delete(key: key)
                }
                httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                let updated = try await serverConfigRepository.delete([server.id])
                await send(.serverRepositoryResponse(.success(updated)))
            } catch {
                await send(.serverRepositoryResponse(.failure(error)))
            }
        }
    }
}
