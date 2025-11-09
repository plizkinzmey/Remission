import ComposableArchitecture
import Foundation

@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        @Presents var alert: AlertState<AlertAction>?
    }

    enum Action: Equatable {
        case task
        case resetTrustButtonTapped
        case resetTrustSucceeded
        case resetTrustFailed(String)
        case alert(PresentationAction<AlertAction>)
    }

    enum AlertAction: Equatable {
        case confirmReset
        case cancelReset
        case dismiss
    }

    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.transmissionTrustStoreClient) var transmissionTrustStoreClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
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

            case .alert(.presented(.cancelReset)):
                state.alert = nil
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func performTrustReset(for server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
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
}
