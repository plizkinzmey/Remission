import ComposableArchitecture
import Foundation

/// Управляет экраном настроек пользователя: интервал polling и автообновление.
@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var serverID: UUID
        var serverName: String
        var connectionEnvironment: ServerConnectionEnvironment?
        var isLoading: Bool = true
        var isSaving: Bool = false
        var pollingIntervalSeconds: Double = 5
        var isAutoRefreshEnabled: Bool = true
        var isTelemetryEnabled: Bool = false
        var isSeedRatioLimitEnabled: Bool = false
        var seedRatioLimitValue: Double = 0
        var persistedPreferences: UserPreferences?
        var persistedSession: SessionState?
        var hasPendingChanges: Bool = false
        var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits = .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        )
        @Presents var alert: AlertState<AlertAction>?

        init(
            serverID: UUID,
            serverName: String,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            isLoading: Bool = true
        ) {
            self.serverID = serverID
            self.serverName = serverName
            self.connectionEnvironment = connectionEnvironment
            self.isLoading = isLoading
        }
    }

    enum Action: Equatable {
        case task
        case teardown
        case pollingIntervalChanged(Double)
        case autoRefreshToggled(Bool)
        case telemetryToggled(Bool)
        case seedRatioLimitChanged(String)
        case downloadLimitChanged(String)
        case uploadLimitChanged(String)
        case preferencesResponse(TaskResult<UserPreferences>)
        case sessionResponse(TaskResult<SessionState>)
        case saveButtonTapped
        case cancelButtonTapped
        case saveResponse(TaskResult<SaveResult>)
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
        case save
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.alert = nil
                if state.persistedPreferences != nil {
                    state.isLoading = false
                    return .merge(
                        observePreferences(serverID: state.serverID),
                        loadSession(environment: state.connectionEnvironment)
                    )
                }
                state.isLoading = true
                return .merge(
                    loadPreferences(serverID: state.serverID),
                    observePreferences(serverID: state.serverID),
                    loadSession(environment: state.connectionEnvironment)
                )

            case .teardown:
                let effects: [Effect<Action>] = [
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.save)
                ]
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

            case .seedRatioLimitChanged(let value):
                guard let parsed = parseRatio(limit: value) else { return .none }
                if parsed > 0 {
                    state.isSeedRatioLimitEnabled = true
                    state.seedRatioLimitValue = parsed
                } else {
                    state.isSeedRatioLimitEnabled = false
                    state.seedRatioLimitValue = 0
                }
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

            case .sessionResponse(.success(let session)):
                state.persistedSession = session
                if state.hasPendingChanges == false {
                    apply(session: session, to: &state)
                }
                return .none

            case .sessionResponse(.failure(let error)):
                state.alert = AlertState {
                    TextState(L10n.tr("settings.alert.sessionFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("settings.alert.close"))
                    }
                } message: {
                    TextState(describe(error))
                }
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
                if let persistedSession = state.persistedSession {
                    apply(session: persistedSession, to: &state)
                }
                state.hasPendingChanges = false
                return .send(.delegate(.closeRequested))

            case .saveResponse(.success(let result)):
                state.isSaving = false
                state.hasPendingChanges = false
                state.persistedPreferences = result.preferences
                state.persistedSession = result.session
                apply(preferences: result.preferences, to: &state)
                apply(session: result.session, to: &state)
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
            }
        }
        .ifLet(\.$alert, action: \.alert)
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
        let seedRatio = SessionState.SeedRatioLimit(
            isEnabled: state.isSeedRatioLimitEnabled,
            value: state.seedRatioLimitValue
        )
        let environment = state.connectionEnvironment
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
                        guard environment != nil else {
                            throw SettingsError.missingConnection
                        }
                        let sessionUpdate = SessionRepository.SessionUpdate(
                            seedRatioLimit: seedRatio)
                        let session = try await withDependencies {
                            if let environment {
                                environment.apply(to: &$0)
                            }
                        } operation: {
                            @Dependency(\.sessionRepository) var sessionRepository:
                                SessionRepository
                            return try await sessionRepository.updateState(sessionUpdate)
                        }
                        return SaveResult(
                            preferences: try await userPreferencesRepository.load(
                                serverID: serverID
                            ),
                            session: session
                        )
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

    private func apply(
        session: SessionState,
        to state: inout State
    ) {
        state.isSeedRatioLimitEnabled = session.seedRatioLimit.isEnabled
        state.seedRatioLimitValue =
            session.seedRatioLimit.isEnabled
            ? session.seedRatioLimit.value
            : 0
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

    private func parseRatio(limit: String) -> Double? {
        let trimmed = limit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    private func loadSession(
        environment: ServerConnectionEnvironment?
    ) -> Effect<Action> {
        .run { send in
            await send(
                .sessionResponse(
                    TaskResult {
                        try await withDependencies {
                            if let environment {
                                environment.apply(to: &$0)
                            }
                        } operation: {
                            @Dependency(\.sessionRepository) var sessionRepository:
                                SessionRepository
                            return try await sessionRepository.fetchState()
                        }
                    }
                )
            )
        }
    }
}

extension SettingsReducer {
    struct SaveResult: Equatable {
        var preferences: UserPreferences
        var session: SessionState
    }

    enum SettingsError: LocalizedError, Sendable {
        case missingConnection

        var errorDescription: String? {
            switch self {
            case .missingConnection:
                return L10n.tr("settings.error.connection")
            }
        }
    }
}
