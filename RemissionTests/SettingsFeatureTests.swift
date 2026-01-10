import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
@Suite("SettingsReducer")
struct SettingsFeatureTests {
    @Test("task загружает настройки и показывает значения")
    func taskLoadsPreferences() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: preferences,
            serverID: serverID
        )

        let testStore = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server"
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = .inMemory(store: store)
        }

        await testStore.send(.task)

        await testStore.receive(.preferencesResponse(.success(preferences))) {
            $0.isLoading = false
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.persistedPreferences = preferences
            $0.hasPendingChanges = false
        }
    }

    @Test("изменения остаются локальными до сохранения")
    func changesStayLocalUntilSave() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: preferences,
            serverID: serverID
        )

        let testStore = TestStore(
            initialState: loadedState(from: preferences, serverID: serverID)
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = .inMemory(store: store)
        }

        await testStore.send(.pollingIntervalChanged(12)) {
            $0.pollingIntervalSeconds = 12
            $0.hasPendingChanges = true
        }

        let snapshot = await store.snapshot(serverID: serverID)
        #expect(snapshot.pollingInterval == preferences.pollingInterval)
    }

    @Test("сохранение применяет изменения и закрывает экран")
    func savePersistsPreferences() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: preferences,
            serverID: serverID
        )

        let testStore = TestStore(
            initialState: loadedState(from: preferences, serverID: serverID)
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = .inMemory(store: store)
        }

        await testStore.send(.downloadLimitChanged("4096")) {
            $0.defaultSpeedLimits.downloadKilobytesPerSecond = 4_096
            $0.hasPendingChanges = true
        }

        await testStore.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.alert = nil
        }

        var expected = preferences
        expected.defaultSpeedLimits = .init(
            downloadKilobytesPerSecond: 4_096,
            uploadKilobytesPerSecond: preferences.defaultSpeedLimits.uploadKilobytesPerSecond
        )

        await testStore.receive(.saveResponse(.success(expected))) {
            $0.isSaving = false
            $0.hasPendingChanges = false
            $0.persistedPreferences = expected
            $0.pollingIntervalSeconds = expected.pollingInterval
            $0.isAutoRefreshEnabled = expected.isAutoRefreshEnabled
            $0.isTelemetryEnabled = expected.isTelemetryEnabled
            $0.defaultSpeedLimits = expected.defaultSpeedLimits
        }

        await testStore.receive(.delegate(.closeRequested))

        let persisted = await store.snapshot(serverID: serverID)
        #expect(persisted.defaultSpeedLimits == expected.defaultSpeedLimits)
    }

    @Test("отмена сбрасывает правки и закрывает экран")
    func cancelRevertsChanges() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: preferences,
            serverID: serverID
        )

        let testStore = TestStore(
            initialState: loadedState(from: preferences, serverID: serverID)
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = .inMemory(store: store)
        }

        await testStore.send(.pollingIntervalChanged(15)) {
            $0.pollingIntervalSeconds = 15
            $0.hasPendingChanges = true
        }

        await testStore.send(.cancelButtonTapped) {
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.hasPendingChanges = false
        }

        await testStore.receive(.delegate(.closeRequested))
    }

    @Test("ошибка сохранения показывает alert")
    func saveFailureShowsAlert() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: preferences,
            serverID: serverID
        )
        await store.markFailure(.updatePollingInterval)

        let testStore = TestStore(
            initialState: loadedState(from: preferences, serverID: serverID)
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = .inMemory(store: store)
        }

        await testStore.send(.pollingIntervalChanged(22)) {
            $0.pollingIntervalSeconds = 22
            $0.hasPendingChanges = true
        }

        let expectedError = InMemoryUserPreferencesRepositoryError.operationFailed(
            .updatePollingInterval
        )

        await testStore.send(.saveButtonTapped) {
            $0.isSaving = true
            $0.alert = nil
        }

        await testStore.receive(.saveResponse(.failure(expectedError))) {
            $0.isSaving = false
            $0.alert = AlertState {
                TextState(L10n.tr("settings.alert.saveFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("settings.alert.close"))
                }
            } message: {
                TextState(expectedError.errorDescription ?? "")
            }
        }
    }
}

private func loadedState(
    from preferences: UserPreferences,
    serverID: UUID
) -> SettingsReducer.State {
    var state = SettingsReducer.State(
        serverID: serverID,
        serverName: "Server",
        isLoading: false
    )
    state.pollingIntervalSeconds = preferences.pollingInterval
    state.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
    state.isTelemetryEnabled = preferences.isTelemetryEnabled
    state.defaultSpeedLimits = preferences.defaultSpeedLimits
    state.persistedPreferences = preferences
    state.hasPendingChanges = false
    return state
}
