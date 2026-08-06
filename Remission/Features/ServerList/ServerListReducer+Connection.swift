import ComposableArchitecture
import Foundation

extension ServerListReducer {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func connectionReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            if state.isPreloaded {
                state.isLoading = false
                return .none
            }
            guard state.isLoading == false else { return .none }
            state.isLoading = true
            return .run { send in
                await send(
                    .serverRepositoryResponse(
                        TaskResult {
                            try await serverConfigRepository.load()
                        }
                    )
                )
            }

        case .serverRepositoryResponse(.success(let servers)):
            state.isLoading = false
            state.servers = IdentifiedArrayOf(uniqueElements: servers)
            let identifiers = Set(servers.map(\.id))
            state.connectionStatuses = Dictionary(
                uniqueKeysWithValues: state.connectionStatuses.filter {
                    identifiers.contains($0.key)
                }
            )
            let shouldAutoSelect =
                servers.count == 1
                && state.hasAutoSelectedSingleServer == false
                && state.serverForm == nil
            if shouldAutoSelect {
                state.hasAutoSelectedSingleServer = true
            }
            // Probe servers asynchronously - filter in a task
            return .run { [servers, shouldAutoSelect] send in
                var serversToProbe: [ServerConfig] = []
                for server in servers {
                    let isSuppressed = await httpWarningPreferencesStore.isSuppressed(
                        server.httpWarningFingerprint)
                    if !server.usesInsecureTransport || isSuppressed {
                        serversToProbe.append(server)
                    }
                }
                for server in serversToProbe {
                    await send(.connectionProbeRequested(server.id))
                }
                if shouldAutoSelect, let server = servers.first {
                    await send(.delegate(.serverSelected(server)))
                }
            }

        case .serverRepositoryResponse(.failure(let error)):
            state.isLoading = false
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverList.alert.refreshFailed.title"),
                message: error.localizedDescription,
                action: .dismiss
            )
            return .none

        case .connectionProbeRequested(let id):
            guard let server = state.servers[id: id] else { return .none }
            // Check httpWarningPreferencesStore asynchronously
            return .run { [server] send in
                let isSuppressed = await httpWarningPreferencesStore.isSuppressed(
                    server.httpWarningFingerprint)
                if !server.usesInsecureTransport || isSuppressed {
                    await send(.startConnectionProbe(server))
                } else {
                    await send(.showHTTPWarning(.probe(id)))
                }
            }

        case .startConnectionProbe(let server):
            return self.startConnectionProbe(state: &state, server: server)

        case .showHTTPWarning(let pending):
            state.pendingHTTPConnection = pending
            state.alert = AlertFactory.httpConnectionWarning(
                confirmAction: .confirmHTTPConnection,
                cancelAction: .cancelHTTPConnection
            )
            return .none

        case .confirmHTTPProbe(let id):
            guard let server = state.servers[id: id] else { return .none }
            return .run { [server] send in
                await httpWarningPreferencesStore.setSuppressed(server.httpWarningFingerprint, true)
                await send(.startConnectionProbe(server))
            }

        case .connectionProbeResponse(let id, .success(let result)):
            state.connectionStatuses[id] = .init(phase: .connected(result.handshake))
            return .send(.storageRequested(id))

        case .connectionProbeResponse(let id, .failure(let error)):
            if case .connected = state.connectionStatuses[id]?.phase {
                return .none
            }
            state.connectionStatuses[id] = .init(phase: .failed(describe(error)))
            return .none

        default:
            return .none
        }
    }

    private func startConnectionProbe(state: inout State, server: ServerConfig) -> Effect<Action> {
        if state.connectionStatuses[server.id]?.isProbing == true {
            return .none
        }
        state.connectionStatuses[server.id] = .init(phase: .probing)
        return .run { [server] send in
            do {
                let password: String?
                if let credentialsKey = server.credentialsKey {
                    guard
                        let credentials = try await credentialsRepository.load(
                            key: credentialsKey
                        )
                    else {
                        throw ServerConnectionEnvironmentFactoryError.missingCredentials
                    }
                    password = credentials.password
                } else {
                    password = nil
                }
                let result = try await serverConnectionProbe.run(
                    .init(server: server, password: password),
                    nil
                )
                await send(.connectionProbeResponse(server.id, .success(result)))
            } catch {
                await send(
                    .connectionProbeResponse(
                        server.id,
                        .failure(error)
                    )
                )
            }
        }
        .cancellable(id: ConnectionCancellationID.connectionProbe(server.id), cancelInFlight: true)
    }
}
