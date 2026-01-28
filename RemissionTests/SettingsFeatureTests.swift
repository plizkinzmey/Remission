import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Settings Feature Tests")
@MainActor
struct SettingsFeatureTests {

    @Test("Task loads preferences and session state")
    func testTask_LoadsData() async {
        let serverID = UUID()
        let prefs = UserPreferences.default
        let session = SessionState.previewActive

        var sessionRepo = SessionRepository.placeholder
        sessionRepo.fetchStateClosure = { @Sendable in session }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            sessionRepository: sessionRepo
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID, serverName: "Test", connectionEnvironment: environment)
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository.loadClosure = { @Sendable _ in prefs }
            $0.userPreferencesRepository.observeClosure = { @Sendable _ in
                AsyncStream { $0.finish() }
            }
        }

        await store.send(SettingsReducer.Action.task)

        await store.receive(SettingsReducer.Action.preferencesResponse(.success(prefs))) {
            $0.isLoading = false
            $0.persistedPreferences = prefs
        }

        await store.receive(SettingsReducer.Action.sessionResponse(.success(session))) {
            $0.persistedSession = session
            $0.isSeedRatioLimitEnabled = session.seedRatioLimit.isEnabled
            $0.seedRatioLimitValue = session.seedRatioLimit.value
        }
    }

    @Test("Polling interval changed sets pending changes")
    func testPollingIntervalChanged() async {
        let store = TestStore(
            initialState: SettingsReducer.State(serverID: UUID(), serverName: "Test")
        ) {
            SettingsReducer()
        }

        await store.send(SettingsReducer.Action.pollingIntervalChanged(10)) {
            $0.pollingIntervalSeconds = 10
            $0.hasPendingChanges = true
        }
    }

    @Test("Save success updates persisted state and notifies delegate")
    func testSave_Success() async {
        let serverID = UUID()
        let initialPrefs = UserPreferences.default
        let initialSession = SessionState.previewActive
        let store = makeStoreForSaveTest(
            serverID: serverID,
            initialPrefs: initialPrefs,
            initialSession: initialSession
        )

        await store.send(SettingsReducer.Action.pollingIntervalChanged(30)) {
            $0.pollingIntervalSeconds = 30
            $0.hasPendingChanges = true
        }

        await store.send(SettingsReducer.Action.saveButtonTapped) {
            $0.isSaving = true
        }

        let saveResult = SettingsReducer.SaveResult(
            preferences: initialPrefs, session: initialSession)
        await store.receive(SettingsReducer.Action.saveResponse(.success(saveResult))) {
            $0.isSaving = false
            $0.hasPendingChanges = false
            $0.persistedPreferences = initialPrefs
            $0.persistedSession = initialSession
            $0.pollingIntervalSeconds = initialPrefs.pollingInterval
            $0.isSeedRatioLimitEnabled = initialSession.seedRatioLimit.isEnabled
            $0.seedRatioLimitValue = initialSession.seedRatioLimit.value
        }

        await store.receive(SettingsReducer.Action.delegate(.closeRequested))
        await store.receive(SettingsReducer.Action.delegate(.pollingIntervalChanged))
    }
}

@MainActor
private func makeStoreForSaveTest(
    serverID: UUID,
    initialPrefs: UserPreferences,
    initialSession: SessionState
) -> TestStore<SettingsReducer.State, SettingsReducer.Action> {
    var sessionRepo = SessionRepository.placeholder
    sessionRepo.updateStateClosure = { @Sendable _ in initialSession }

    let environment = ServerConnectionEnvironment.testEnvironment(
        server: .sample,
        sessionRepository: sessionRepo
    )

    return TestStore(
        initialState: SettingsReducer.State(
            serverID: serverID,
            serverName: "Test",
            connectionEnvironment: environment,
            isLoading: false
        )
    ) {
        SettingsReducer()
    } withDependencies: {
        $0.userPreferencesRepository.loadClosure = { @Sendable _ in initialPrefs }
        $0.userPreferencesRepository.setAutoRefreshEnabledClosure = { @Sendable _, _ in
            initialPrefs
        }
        $0.userPreferencesRepository.updatePollingIntervalClosure = { @Sendable _, _ in
            initialPrefs
        }
        $0.userPreferencesRepository.updateDefaultSpeedLimitsClosure = { @Sendable _, _ in
            initialPrefs
        }
        $0.userPreferencesRepository.setTelemetryEnabledClosure = { @Sendable _, _ in
            initialPrefs
        }
    }
}
