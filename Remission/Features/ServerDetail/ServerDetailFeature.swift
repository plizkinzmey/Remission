import ComposableArchitecture
import Foundation

// swiftlint:disable nesting type_body_length

/// Главный reducer экрана деталей сервера: отвечает за подключение, управление
/// сервером и встраивает `TorrentListReducer` для отображения торрентов.
@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        @Presents var alert: AlertState<AlertAction>?
        @Presents var editor: ServerEditorReducer.State?
        @Presents var torrentDetail: TorrentDetailReducer.State?
        var isDeleting: Bool = false
        var connectionState: ConnectionState = .init()
        var connectionEnvironment: ServerConnectionEnvironment?
        var torrentList: TorrentListReducer.State = .init()

        init(server: ServerConfig, startEditing: Bool = false) {
            self.server = server
            if startEditing {
                self.editor = ServerEditorReducer.State(server: server)
            }
        }
    }

    enum Action: Equatable {
        case task
        case editButtonTapped
        case deleteButtonTapped
        case deleteCompleted(DeletionResult)
        case httpWarningResetButtonTapped
        case resetTrustButtonTapped
        case resetTrustSucceeded
        case resetTrustFailed(String)
        case retryConnectionButtonTapped
        case connectionResponse(TaskResult<ConnectionResponse>)
        case torrentList(TorrentListReducer.Action)
        case editor(PresentationAction<ServerEditorReducer.Action>)
        case torrentDetail(PresentationAction<TorrentDetailReducer.Action>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case confirmReset
        case cancelReset
        case dismiss
        case confirmDeletion
        case cancelDeletion
    }

    enum Delegate: Equatable {
        case serverUpdated(ServerConfig)
        case serverDeleted(UUID)
        case torrentSelected(Torrent.Identifier)
    }

    struct DeletionError: Equatable, Error {
        var message: String
    }

    enum DeletionResult: Equatable {
        case success
        case failure(DeletionError)
    }

    struct ConnectionState: Equatable {
        struct Ready: Equatable {
            var fingerprint: String
            var handshake: TransmissionHandshakeResult
        }

        struct Failure: Equatable {
            var message: String
        }

        enum Phase: Equatable {
            case idle
            case connecting
            case ready(Ready)
            case failed(Failure)
        }

        var phase: Phase = .idle

        var failureMessage: String? {
            if case .failed(let failure) = phase {
                return failure.message
            }
            return nil
        }
    }

    struct ConnectionResponse: Equatable {
        var environment: ServerConnectionEnvironment
        var handshake: TransmissionHandshakeResult
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.transmissionTrustStoreClient) var transmissionTrustStoreClient
    @Dependency(\.serverConnectionEnvironmentFactory) var serverConnectionEnvironmentFactory

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return startConnectionIfNeeded(state: &state)

            case .retryConnectionButtonTapped:
                return startConnection(state: &state, force: true)

            case .editButtonTapped:
                state.editor = ServerEditorReducer.State(server: state.server)
                return .none

            case .deleteButtonTapped:
                state.alert = makeDeleteAlert()
                return .none

            case .deleteCompleted(.success):
                state.isDeleting = false
                return .merge(
                    .cancel(id: ConnectionCancellationID.connection),
                    .send(.delegate(.serverDeleted(state.server.id)))
                )

            case .deleteCompleted(.failure(let error)):
                state.isDeleting = false
                state.alert = AlertState {
                    TextState("Не удалось удалить сервер")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Понятно")
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .httpWarningResetButtonTapped:
                httpWarningPreferencesStore.reset(state.server.httpWarningFingerprint)
                state.alert = AlertState {
                    TextState("Предупреждения сброшены")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Готово")
                    }
                } message: {
                    TextState("Мы снова предупредим перед подключением по HTTP.")
                }
                return .none

            case .resetTrustButtonTapped:
                state.alert = AlertState {
                    TextState("Сбросить доверие?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmReset) {
                        TextState("Сбросить")
                    }
                    ButtonState(role: .cancel, action: .cancelReset) {
                        TextState("Отмена")
                    }
                } message: {
                    TextState(
                        "Удалим сохранённые отпечатки сертификатов и решения \"Не предупреждать\"."
                    )
                }
                return .none

            case .resetTrustSucceeded:
                state.alert = AlertState {
                    TextState("Доверие сброшено")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Готово")
                    }
                } message: {
                    TextState("При следующем подключении мы снова спросим подтверждение.")
                }
                return .none

            case .resetTrustFailed(let message):
                state.alert = AlertState {
                    TextState("Не удалось сбросить доверие")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Понятно")
                    }
                } message: {
                    TextState(message)
                }
                return .none

            case .alert(.presented(.confirmReset)):
                state.alert = nil
                return performTrustReset(for: state.server)

            case .alert(.presented(.confirmDeletion)):
                state.alert = nil
                guard state.isDeleting == false else { return .none }
                state.isDeleting = true
                return deleteServer(state.server)

            case .alert(.presented(.cancelReset)):
                state.alert = nil
                return .none

            case .alert(.presented(.cancelDeletion)):
                state.alert = nil
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                return .none

            case .connectionResponse(.success(let response)):
                state.connectionEnvironment = response.environment
                state.torrentDetail?.applyConnectionEnvironment(response.environment)
                state.connectionState.phase = .ready(
                    .init(
                        fingerprint: response.environment.fingerprint,
                        handshake: response.handshake
                    )
                )
                state.torrentList.connectionEnvironment = response.environment
                var effects: Effect<Action> = .send(.torrentList(.task))
                if ProcessInfo.processInfo.arguments.contains(
                    "--ui-testing-fixture=torrent-list-sample"
                ) {
                    effects = .merge(
                        effects,
                        .send(.torrentList(.refreshRequested))
                    )
                }
                return effects

            case .connectionResponse(.failure(let error)):
                state.connectionEnvironment = nil
                state.torrentDetail?.applyConnectionEnvironment(nil)
                let message = describe(error)
                state.connectionState.phase = .failed(.init(message: message))
                state.alert = AlertState.connectionFailure(message: message)
                let teardown: Effect<Action> =
                    state.torrentList.connectionEnvironment != nil
                    ? .send(.torrentList(.teardown))
                    : .none
                state.torrentList = .init()
                return teardown

            case .editor(.presented(.delegate(.didUpdate(let server)))):
                let shouldReconnect =
                    state.server.connectionFingerprint != server.connectionFingerprint
                state.server = server
                state.editor = nil
                let teardownEffect: Effect<Action> =
                    shouldReconnect ? .send(.torrentList(.teardown)) : .none
                if shouldReconnect {
                    state.torrentList = .init()
                }
                let connectionEffect =
                    shouldReconnect
                    ? startConnection(state: &state, force: true) : .none
                return .merge(
                    teardownEffect,
                    connectionEffect,
                    .send(.delegate(.serverUpdated(server)))
                )

            case .editor(.presented(.delegate(.cancelled))):
                state.editor = nil
                return .none

            case .editor:
                return .none

            case .torrentList(.delegate(.openTorrent(let id))):
                guard let selectedItem = state.torrentList.items[id: id] else {
                    return .none
                }
                var detailState = TorrentDetailReducer.State(
                    torrent: selectedItem.torrent
                )
                detailState.applyConnectionEnvironment(state.torrentList.connectionEnvironment)
                state.torrentDetail = detailState
                return .none

            case .torrentList(.delegate(.addTorrentRequested)):
                state.alert = makeAddTorrentPlaceholderAlert()
                return .none

            case .torrentList:
                return .none

            case .torrentDetail(.presented(.delegate(.torrentRemoved(let identifier)))):
                state.torrentDetail = nil
                state.torrentList.items.remove(id: identifier)
                return .send(.torrentList(.refreshRequested))

            case .torrentDetail(.presented(.delegate(.closeRequested))):
                state.torrentDetail = nil
                return .none

            case .torrentDetail:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$editor, action: \.editor) {
            ServerEditorReducer()
        }
        .ifLet(\.$torrentDetail, action: \.torrentDetail) {
            TorrentDetailReducer()
        }
        Scope(state: \.torrentList, action: \.torrentList) {
            TorrentListReducer()
        }
    }

    private enum ConnectionCancellationID {
        case connection
    }

    /// Проверяет, нужно ли переустанавливать подключение (изменился ли fingerprint
    /// или окружение невалидно) и инициирует коннект при необходимости.
    private func startConnectionIfNeeded(
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

    /// Запускает процесс подключения к серверу, учитывая флаг принудительного запуска.
    private func startConnection(
        state: inout State,
        force: Bool
    ) -> Effect<Action> {
        guard case .connecting = state.connectionState.phase,
            force == false
        else {
            state.connectionEnvironment = nil
            state.connectionState.phase = .connecting
            return connect(server: state.server)
        }

        return .none
    }

    /// Создаёт `ServerConnectionEnvironment` и выполняет handshake Transmission.
    private func connect(server: ServerConfig) -> Effect<Action> {
        .run { send in
            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await serverConnectionEnvironmentFactory.make(server)
                        let handshake = try await environment.dependencies.transmissionClient
                            .performHandshake()
                        return ConnectionResponse(environment: environment, handshake: handshake)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
    }

    private func performTrustReset(for server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                await send(.resetTrustSucceeded)
            } catch {
                let message = (error as NSError).localizedDescription
                await send(.resetTrustFailed(message))
            }
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
                _ = try await serverConfigRepository.delete([server.id])
                await send(.deleteCompleted(.success))
            } catch {
                let message = (error as NSError).localizedDescription
                await send(.deleteCompleted(.failure(DeletionError(message: message))))
            }
        }
    }

    private func makeDeleteAlert() -> AlertState<AlertAction> {
        AlertState {
            TextState("Удалить сервер?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeletion) {
                TextState("Удалить")
            }
            ButtonState(role: .cancel, action: .cancelDeletion) {
                TextState("Отмена")
            }
        } message: {
            TextState("Сервер и сохранённые креды будут удалены без возможности восстановления.")
        }
    }

    private func makeAddTorrentPlaceholderAlert() -> AlertState<AlertAction> {
        AlertState {
            TextState("Добавление торрента")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Готово")
            }
        } message: {
            TextState("Экран добавления пока не реализован. Сообщим, как только появится.")
        }
    }
}

private func describe(_ error: Error) -> String {
    if let localized = error as? LocalizedError {
        if let description = localized.errorDescription {
            if description.isEmpty == false {
                return description
            }
        }
    }

    let nsError = error as NSError
    let description = nsError.localizedDescription
    return description.isEmpty ? String(describing: error) : description
}

extension AlertState where Action == ServerDetailReducer.AlertAction {
    static func connectionFailure(message: String) -> Self {
        AlertState {
            TextState("Не удалось подключиться")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Понятно")
            }
        } message: {
            TextState(message)
        }
    }
}

// swiftlint:enable nesting type_body_length
