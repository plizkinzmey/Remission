import ComposableArchitecture
import Foundation

/// Управляет экраном настроек пользователя: интервал polling и автообновление.
@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = true
        var pollingIntervalSeconds: Double = 5
        var isAutoRefreshEnabled: Bool = true
        var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits = .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        )
        @Presents var alert: AlertState<AlertAction>?
    }

    enum Action: Equatable {
        case task
        case teardown
        case pollingIntervalChanged(Double)
        case autoRefreshToggled(Bool)
        case downloadLimitChanged(String)
        case uploadLimitChanged(String)
        case preferencesResponse(TaskResult<UserPreferences>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case closeRequested
    }

    @Dependency(\.userPreferencesRepository) var userPreferencesRepository

    private enum CancelID {
        case observation
        case updatePollingInterval
        case setAutoRefresh
        case updateSpeedLimits
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                state.alert = nil
                return .merge(
                    loadPreferences(),
                    observePreferences()
                )

            case .teardown:
                return .merge(
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.updatePollingInterval),
                    .cancel(id: CancelID.setAutoRefresh),
                    .cancel(id: CancelID.updateSpeedLimits)
                )

            case .pollingIntervalChanged(let seconds):
                state.pollingIntervalSeconds = seconds
                return updatePollingInterval(seconds)

            case .autoRefreshToggled(let isEnabled):
                state.isAutoRefreshEnabled = isEnabled
                return setAutoRefreshEnabled(isEnabled)

            case .downloadLimitChanged(let value):
                state.defaultSpeedLimits.downloadKilobytesPerSecond = parse(limit: value)
                return updateDefaultSpeedLimits(state.defaultSpeedLimits)

            case .uploadLimitChanged(let value):
                state.defaultSpeedLimits.uploadKilobytesPerSecond = parse(limit: value)
                return updateDefaultSpeedLimits(state.defaultSpeedLimits)

            case .preferencesResponse(.success(let preferences)):
                state.isLoading = false
                state.pollingIntervalSeconds = preferences.pollingInterval
                state.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
                state.defaultSpeedLimits = preferences.defaultSpeedLimits
                state.alert = nil
                return .none

            case .preferencesResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("Не удалось сохранить настройки")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Закрыть")
                    }
                } message: {
                    TextState(describe(error))
                }
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func loadPreferences() -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load()
                    }
                )
            )
        }
    }

    private func observePreferences() -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe()
            for await preferences in stream {
                await send(.preferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.observation, cancelInFlight: true)
    }

    private func updatePollingInterval(_ seconds: Double) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.updatePollingInterval(seconds)
                    }
                )
            )
        }
        .cancellable(id: CancelID.updatePollingInterval, cancelInFlight: true)
    }

    private func setAutoRefreshEnabled(_ isEnabled: Bool) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.setAutoRefreshEnabled(isEnabled)
                    }
                )
            )
        }
        .cancellable(id: CancelID.setAutoRefresh, cancelInFlight: true)
    }

    private func updateDefaultSpeedLimits(
        _ limits: UserPreferences.DefaultSpeedLimits
    ) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.updateDefaultSpeedLimits(limits)
                    }
                )
            )
        }
        .cancellable(id: CancelID.updateSpeedLimits, cancelInFlight: true)
    }

    private func describe(_ error: Error) -> String {
        guard let localized = error as? LocalizedError,
            let message = localized.errorDescription,
            message.isEmpty == false
        else {
            return String(describing: error)
        }
        return message
    }

    private func parse(limit: String) -> Int? {
        let trimmed = limit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }
}
