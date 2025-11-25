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
        var isTelemetryEnabled: Bool = false
        var persistedPreferences: UserPreferences?
        var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits = .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        )
        @Presents var alert: AlertState<AlertAction>?
        @Presents var diagnostics: DiagnosticsReducer.State?
    }

    enum Action: Equatable {
        case task
        case teardown
        case pollingIntervalChanged(Double)
        case autoRefreshToggled(Bool)
        case telemetryToggled(Bool)
        case downloadLimitChanged(String)
        case uploadLimitChanged(String)
        case preferencesResponse(TaskResult<UserPreferences>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case diagnosticsButtonTapped
        case diagnostics(PresentationAction<DiagnosticsReducer.Action>)
        case diagnosticsDismissed
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
        case setTelemetry
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
                var effects: [Effect<Action>] = [
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.updatePollingInterval),
                    .cancel(id: CancelID.setAutoRefresh),
                    .cancel(id: CancelID.setTelemetry),
                    .cancel(id: CancelID.updateSpeedLimits)
                ]
                if state.diagnostics != nil {
                    effects.append(.send(.diagnostics(.presented(.teardown))))
                }
                return .merge(effects)

            case .pollingIntervalChanged(let seconds):
                state.pollingIntervalSeconds = seconds
                return updatePollingInterval(seconds)

            case .autoRefreshToggled(let isEnabled):
                state.isAutoRefreshEnabled = isEnabled
                return setAutoRefreshEnabled(isEnabled)

            case .telemetryToggled(let isEnabled):
                state.isTelemetryEnabled = isEnabled
                return setTelemetryEnabled(isEnabled)

            case .downloadLimitChanged(let value):
                state.defaultSpeedLimits.downloadKilobytesPerSecond = parse(limit: value)
                return updateDefaultSpeedLimits(state.defaultSpeedLimits)

            case .uploadLimitChanged(let value):
                state.defaultSpeedLimits.uploadKilobytesPerSecond = parse(limit: value)
                return updateDefaultSpeedLimits(state.defaultSpeedLimits)

            case .preferencesResponse(.success(let preferences)):
                state.isLoading = false
                state.persistedPreferences = preferences
                state.pollingIntervalSeconds = preferences.pollingInterval
                state.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
                state.isTelemetryEnabled = preferences.isTelemetryEnabled
                state.defaultSpeedLimits = preferences.defaultSpeedLimits
                state.alert = nil
                return .none

            case .preferencesResponse(.failure(let error)):
                state.isLoading = false
                if let persisted = state.persistedPreferences {
                    state.pollingIntervalSeconds = persisted.pollingInterval
                    state.isAutoRefreshEnabled = persisted.isAutoRefreshEnabled
                    state.isTelemetryEnabled = persisted.isTelemetryEnabled
                    state.defaultSpeedLimits = persisted.defaultSpeedLimits
                }
                state.alert = AlertState {
                    TextState(L10n.tr("settings.alert.saveFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("settings.alert.close"))
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

            case .diagnosticsButtonTapped:
                state.diagnostics = DiagnosticsReducer.State()
                return .none

            case .diagnostics(.presented(.delegate(.closeRequested))):
                return .concatenate(
                    .send(.diagnostics(.presented(.teardown))),
                    .send(.diagnosticsDismissed)
                )

            case .diagnostics(.dismiss):
                return .concatenate(
                    .send(.diagnostics(.presented(.teardown))),
                    .send(.diagnosticsDismissed)
                )

            case .diagnosticsDismissed:
                state.diagnostics = nil
                return .none

            case .diagnostics(.presented) where state.diagnostics == nil:
                return .none

            case .diagnostics:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$diagnostics, action: \.diagnostics) {
            DiagnosticsReducer()
        }
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

    private func setTelemetryEnabled(_ isEnabled: Bool) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.setTelemetryEnabled(isEnabled)
                    }
                )
            )
        }
        .cancellable(id: CancelID.setTelemetry, cancelInFlight: true)
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
