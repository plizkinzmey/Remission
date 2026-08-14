import ComposableArchitecture
import Foundation

extension ServerListReducer {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func managementReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            #if os(iOS)
                return .send(.delegate(.addServerRequested))
            #else
                state.serverForm = ServerFormReducer.State(mode: .add)
                return .none
            #endif

        case .serverTapped(let id):
            guard let server = state.servers[id: id] else {
                return .none
            }
            // Check httpWarningPreferencesStore asynchronously
            return .run { [server] send in
                let isSuppressed = await httpWarningPreferencesStore.isSuppressed(
                    server.httpWarningFingerprint)
                if !server.usesInsecureTransport || isSuppressed {
                    await send(.delegate(.serverSelected(server)))
                } else {
                    await send(.showHTTPWarning(.selection(server)))
                }
            }

        case .showHTTPWarning(let pending):
            state.pendingHTTPConnection = pending
            state.alert = AlertFactory.httpConnectionWarning(
                confirmAction: .confirmHTTPConnection,
                cancelAction: .cancelHTTPConnection
            )
            return .none

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

        case .alert(.presented(.confirmHTTPConnection)):
            guard let pending = state.pendingHTTPConnection else { return .none }
            state.pendingHTTPConnection = nil
            state.alert = nil
            return .run { [pending] send in
                switch pending {
                case .probe(let id):
                    // Need to get server from the dependency since we can't access state here
                    // This will be handled by connectionReducer which has the server
                    await send(.confirmHTTPProbe(id))
                case .selection(let server):
                    await httpWarningPreferencesStore.setSuppressed(
                        server.httpWarningFingerprint, true)
                    await send(.delegate(.serverSelected(server)))
                }
            }

        case .confirmHTTPProbe:
            // This action is handled in connectionReducer where we have access to the server
            return .none

        case .alert(.presented(.cancelHTTPConnection)):
            state.pendingHTTPConnection = nil
            state.alert = nil
            return .none

        case .alert(.dismiss):
            state.pendingHTTPConnection = nil
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
                await httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
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
