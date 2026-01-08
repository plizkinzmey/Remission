import ComposableArchitecture
import Foundation

/// Управляет экраном настроек пользователя: интервал polling и автообновление.
@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var serverID: UUID
        var serverName: String
        var isLoading: Bool = true
        var isSaving: Bool = false
        var pollingIntervalSeconds: Double = 5
        var isAutoRefreshEnabled: Bool = true
        var isTelemetryEnabled: Bool = false
        var persistedPreferences: UserPreferences?
        var hasPendingChanges: Bool = false
        var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits = .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        )
        @Presents var alert: AlertState<AlertAction>?
        @Presents var diagnostics: DiagnosticsReducer.State?

        init(
            serverID: UUID,
            serverName: String,
            isLoading: Bool = true
        ) {
            self.serverID = serverID
            self.serverName = serverName
            self.isLoading = isLoading
        }
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
        case saveButtonTapped
        case cancelButtonTapped
        case saveResponse(TaskResult<UserPreferences>)
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
        case save
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.alert = nil
                if state.persistedPreferences != nil {
                    state.isLoading = false
                    return observePreferences(serverID: state.serverID)
                }
                state.isLoading = true
                return .merge(
                    loadPreferences(serverID: state.serverID),
                    observePreferences(serverID: state.serverID)
                )

            case .teardown:
                var effects: [Effect<Action>] = [
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.save)
                ]
                if state.diagnostics != nil {
                    effects.append(.send(.diagnostics(.presented(.teardown))))
                }
                return .merge(effects)

            case .pollingIntervalChanged(let seconds):
                state.pollingIntervalSeconds = seconds
                state.hasPendingChanges = true
                return .none

            case .autoRefreshToggled(let isEnabled):
                state.isAutoRefreshEnabled = isEnabled
                state.hasPendingChanges = true
                return .none

            case .telemetryToggled(let isEnabled):
                state.isTelemetryEnabled = isEnabled
                state.hasPendingChanges = true
                return .none

            case .downloadLimitChanged(let value):
                state.defaultSpeedLimits.downloadKilobytesPerSecond = parse(limit: value)
                state.hasPendingChanges = true
                return .none

            case .uploadLimitChanged(let value):
                state.defaultSpeedLimits.uploadKilobytesPerSecond = parse(limit: value)
                state.hasPendingChanges = true
                return .none

            case .preferencesResponse(.success(let preferences)):
                state.isLoading = false
                state.persistedPreferences = preferences
                if state.hasPendingChanges == false {
                    apply(preferences: preferences, to: &state)
                }
                state.alert = nil
                return .none

            case .preferencesResponse(.failure(let error)):
                state.isLoading = false
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

            case .saveButtonTapped:
                state.isSaving = true
                state.alert = nil
                return savePreferences(from: state)

            case .cancelButtonTapped:
                if let persisted = state.persistedPreferences {
                    apply(preferences: persisted, to: &state)
                }
                state.hasPendingChanges = false
                return .send(.delegate(.closeRequested))

            case .saveResponse(.success(let preferences)):
                state.isSaving = false
                state.hasPendingChanges = false
                state.persistedPreferences = preferences
                apply(preferences: preferences, to: &state)
                return .send(.delegate(.closeRequested))

            case .saveResponse(.failure(let error)):
                state.isSaving = false
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

    private func loadPreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
    }

    private func observePreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe(serverID: serverID)
            for await preferences in stream {
                await send(.preferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.observation, cancelInFlight: true)
    }

    private func savePreferences(from state: State) -> Effect<Action> {
        let serverID = state.serverID
        let pollingInterval = state.pollingIntervalSeconds
        let isAutoRefreshEnabled = state.isAutoRefreshEnabled
        let isTelemetryEnabled = state.isTelemetryEnabled
        let limits = state.defaultSpeedLimits
        return .run { send in
            await send(
                .saveResponse(
                    TaskResult {
                        _ = try await userPreferencesRepository.setAutoRefreshEnabled(
                            serverID: serverID,
                            isAutoRefreshEnabled
                        )
                        _ = try await userPreferencesRepository.updatePollingInterval(
                            serverID: serverID,
                            pollingInterval
                        )
                        _ = try await userPreferencesRepository.updateDefaultSpeedLimits(
                            serverID: serverID,
                            limits
                        )
                        _ = try await userPreferencesRepository.setTelemetryEnabled(
                            serverID: serverID,
                            isTelemetryEnabled
                        )
                        return try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
        .cancellable(id: CancelID.save, cancelInFlight: true)
    }

    private func apply(
        preferences: UserPreferences,
        to state: inout State
    ) {
        state.pollingIntervalSeconds = preferences.pollingInterval
        state.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
        state.isTelemetryEnabled = preferences.isTelemetryEnabled
        state.defaultSpeedLimits = preferences.defaultSpeedLimits
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
