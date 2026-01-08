import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
@Suite("SettingsReducer")
struct SettingsFeatureTests {}

extension SettingsFeatureTests {
    @Test("task загружает настройки и показывает значения")
    func taskLoadsPreferences() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let repository = UserPreferencesRepository(
            load: { _ in preferences },
            updatePollingInterval: { _, _ in preferences },
            setAutoRefreshEnabled: { _, _ in preferences },
            setTelemetryEnabled: { _, _ in preferences },
            updateDefaultSpeedLimits: { _, _ in preferences },
            observe: { _ in
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server"
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }

        await store.send(.task)

        await store.receive(.preferencesResponse(.success(preferences))) {
            $0.isLoading = false
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.persistedPreferences = preferences
        }
    }

    @Test("изменение интервала вызывает updatePollingInterval")
    func changingPollingIntervalSavesPreference() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let intervalRecorder = LockedValue<[Double]>([])
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { _ in preferences },
            updatePollingInterval: { _, interval in
                intervalRecorder.withValue { $0.append(interval) }
                var updated = preferences
                updated.pollingInterval = interval
                await continuationBox.yield(updated)
                return updated
            },
            setAutoRefreshEnabled: { _, _ in preferences },
            setTelemetryEnabled: { _, _ in preferences },
            updateDefaultSpeedLimits: { _, _ in preferences },
            observe: { _ in
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server",
                isLoading: false
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        let targetInterval: Double = 12
        await store.send(.pollingIntervalChanged(targetInterval)) {
            $0.pollingIntervalSeconds = 12
        }

        var expectedPreferences = preferences
        expectedPreferences.pollingInterval = targetInterval

        await store.receive(.preferencesResponse(.success(expectedPreferences))) {
            $0.pollingIntervalSeconds = targetInterval
            $0.isTelemetryEnabled = expectedPreferences.isTelemetryEnabled
            $0.persistedPreferences = expectedPreferences
        }

        let calls = intervalRecorder.value
        #expect(calls == [12])

        await continuationBox.finish()
    }

    @Test("изменение лимитов скорости сохраняет и обновляет состояние")
    func changingSpeedLimitsSavesPreference() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let limitsRecorder = LockedValue<[UserPreferences.DefaultSpeedLimits]>([])

        let repository = makeFinishedRepository(preferences: preferences) { limits in
            limitsRecorder.withValue { $0.append(limits) }
            var updated = preferences
            updated.defaultSpeedLimits = limits
            return updated
        }

        var initialState = SettingsReducer.State(
            serverID: serverID,
            serverName: "Server",
            isLoading: false
        )
        initialState.defaultSpeedLimits = preferences.defaultSpeedLimits

        let store = TestStore(
            initialState: initialState
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        let downloadOnly = UserPreferences.DefaultSpeedLimits(
            downloadKilobytesPerSecond: 512,
            uploadKilobytesPerSecond: preferences.defaultSpeedLimits.uploadKilobytesPerSecond
        )
        await store.send(.downloadLimitChanged("512")) {
            $0.defaultSpeedLimits.downloadKilobytesPerSecond = 512
        }

        var updatedPreferences = preferences
        updatedPreferences.defaultSpeedLimits = downloadOnly
        await store.receive(.preferencesResponse(.success(updatedPreferences))) {
            $0.defaultSpeedLimits = downloadOnly
            $0.isTelemetryEnabled = updatedPreferences.isTelemetryEnabled
            $0.persistedPreferences = updatedPreferences
        }

        let bothLimits = UserPreferences.DefaultSpeedLimits(
            downloadKilobytesPerSecond: 512,
            uploadKilobytesPerSecond: 256
        )
        await store.send(.uploadLimitChanged("256")) {
            $0.defaultSpeedLimits.uploadKilobytesPerSecond = 256
        }

        updatedPreferences.defaultSpeedLimits = bothLimits
        await store.receive(.preferencesResponse(.success(updatedPreferences))) {
            $0.defaultSpeedLimits = bothLimits
            $0.isTelemetryEnabled = updatedPreferences.isTelemetryEnabled
            $0.persistedPreferences = updatedPreferences
        }

        #expect(limitsRecorder.value == [downloadOnly, bothLimits])
    }

    @Test("переключатель телеметрии сохраняет значение")
    func telemetryToggleSavesPreference() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let toggleRecorder = LockedValue<[Bool]>([])
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { _ in preferences },
            updatePollingInterval: { _, _ in preferences },
            setAutoRefreshEnabled: { _, _ in preferences },
            setTelemetryEnabled: { _, isEnabled in
                toggleRecorder.withValue { $0.append(isEnabled) }
                var updated = preferences
                updated.isTelemetryEnabled = isEnabled
                await continuationBox.yield(updated)
                return updated
            },
            updateDefaultSpeedLimits: { _, _ in preferences },
            observe: { _ in
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server",
                isLoading: false
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.telemetryToggled(true)) {
            $0.isTelemetryEnabled = true
        }

        var expected = preferences
        expected.isTelemetryEnabled = true

        await store.receive(.preferencesResponse(.success(expected))) {
            $0.isTelemetryEnabled = expected.isTelemetryEnabled
            $0.persistedPreferences = expected
        }

        #expect(toggleRecorder.value == [true])

        await continuationBox.finish()
    }

    @Test("observe поток обновляет состояние")
    func observeStreamUpdatesState() async {
        let preferences = DomainFixtures.userPreferences
        let serverID = UUID()
        let continuationBox = PreferencesContinuationBox()

        let repository = makeObservingRepository(
            preferences: preferences,
            continuationBox: continuationBox
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server"
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.preferencesResponse(.success(preferences))) {
            $0.isLoading = false
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.persistedPreferences = preferences
        }

        var updated = preferences
        updated.pollingInterval = 30
        updated.isAutoRefreshEnabled = false
        updated.defaultSpeedLimits = .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: 512
        )
        await continuationBox.yield(updated)

        await store.receive(.preferencesResponse(.success(updated))) {
            $0.pollingIntervalSeconds = 30
            $0.isAutoRefreshEnabled = false
            $0.isTelemetryEnabled = updated.isTelemetryEnabled
            $0.defaultSpeedLimits = updated.defaultSpeedLimits
            $0.persistedPreferences = updated
        }

        await continuationBox.finish()
    }

    @Test("ошибка загрузки показывает alert и снимает индикатор загрузки")
    func loadFailureShowsAlert() async {
        let serverID = UUID()
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "ошибка" }
        }

        let repository = UserPreferencesRepository(
            load: { _ in throw DummyError.failed },
            updatePollingInterval: { _, _ in throw DummyError.failed },
            setAutoRefreshEnabled: { _, _ in throw DummyError.failed },
            setTelemetryEnabled: { _, _ in throw DummyError.failed },
            updateDefaultSpeedLimits: { _, _ in throw DummyError.failed },
            observe: { _ in
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(
                serverID: serverID,
                serverName: "Server"
            )
        ) {
            SettingsReducer()
        } withDependencies: {
            $0.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.preferencesResponse(.failure(DummyError.failed))) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(L10n.tr("settings.alert.saveFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("settings.alert.close"))
                }
            } message: {
                TextState("ошибка")
            }
        }
    }

    @Test("успешное сохранение возвращает сохранённые значения")
    func successfulSaveUpdatesPersistedPreferences() async {
        let preferences = DomainFixtures.userPreferences
        let preferencesStore = DomainFixtures.makeUserPreferencesStore(preferences: preferences)
        let serverID = UUID()

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences, serverID: serverID),
            preferencesStore: preferencesStore,
            serverID: serverID
        )

        await store.send(.downloadLimitChanged("4096")) {
            $0.defaultSpeedLimits.downloadKilobytesPerSecond = 4_096
        }

        var expected = preferences
        expected.defaultSpeedLimits = .init(
            downloadKilobytesPerSecond: 4_096,
            uploadKilobytesPerSecond: preferences.defaultSpeedLimits.uploadKilobytesPerSecond
        )

        await store.receive(.preferencesResponse(.success(expected))) {
            $0.defaultSpeedLimits = expected.defaultSpeedLimits
            $0.isTelemetryEnabled = expected.isTelemetryEnabled
            $0.persistedPreferences = expected
        }

        let persisted = await preferencesStore.snapshot(serverID: serverID)
        #expect(persisted.defaultSpeedLimits == expected.defaultSpeedLimits)
    }

    @Test("ошибка сохранения телеметрии откатывает состояние")
    func telemetryToggleFailureRollsBackState() async {
        var preferences = DomainFixtures.userPreferences
        preferences.isTelemetryEnabled = true
        let preferencesStore = DomainFixtures.makeUserPreferencesStore(preferences: preferences)
        await preferencesStore.markFailure(.setTelemetryEnabled)
        let serverID = UUID()

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences, serverID: serverID),
            preferencesStore: preferencesStore,
            serverID: serverID
        )

        let expectedError = InMemoryUserPreferencesRepositoryError.operationFailed(
            .setTelemetryEnabled)

        await store.send(.telemetryToggled(false)) {
            $0.isTelemetryEnabled = false
        }

        await store.receive(.preferencesResponse(.failure(expectedError))) {
            $0.isLoading = false
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.persistedPreferences = preferences
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

        let persisted = await preferencesStore.snapshot(serverID: serverID)
        #expect(persisted.isTelemetryEnabled == true)
    }

    @Test("ошибка сохранения откатывает состояние и показывает alert")
    func saveFailureRollsBackState() async {
        let preferences = DomainFixtures.userPreferences
        let preferencesStore = DomainFixtures.makeUserPreferencesStore(preferences: preferences)
        await preferencesStore.markFailure(.updatePollingInterval)
        let serverID = UUID()

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences, serverID: serverID),
            preferencesStore: preferencesStore,
            serverID: serverID
        )

        let expectedError = InMemoryUserPreferencesRepositoryError.operationFailed(
            .updatePollingInterval)
        let newInterval: Double = 22

        await store.send(.pollingIntervalChanged(newInterval)) {
            $0.pollingIntervalSeconds = newInterval
        }

        await store.receive(.preferencesResponse(.failure(expectedError))) {
            $0.isLoading = false
            $0.pollingIntervalSeconds = preferences.pollingInterval
            $0.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            $0.isTelemetryEnabled = preferences.isTelemetryEnabled
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.persistedPreferences = preferences
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

        let persisted = await preferencesStore.snapshot(serverID: serverID)
        #expect(persisted.pollingInterval == preferences.pollingInterval)
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
    return state
}

private func makeFinishedRepository(
    preferences: UserPreferences,
    updateDefaultSpeedLimits:
        @escaping @Sendable (UserPreferences.DefaultSpeedLimits) async throws -> UserPreferences
) -> UserPreferencesRepository {
    UserPreferencesRepository(
        load: { _ in preferences },
        updatePollingInterval: { _, _ in preferences },
        setAutoRefreshEnabled: { _, _ in preferences },
        setTelemetryEnabled: { _, _ in preferences },
        updateDefaultSpeedLimits: { _, limits in
            try await updateDefaultSpeedLimits(limits)
        },
        observe: { _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    )
}

private func makeObservingRepository(
    preferences: UserPreferences,
    continuationBox: PreferencesContinuationBox
) -> UserPreferencesRepository {
    UserPreferencesRepository(
        load: { _ in preferences },
        updatePollingInterval: { _, _ in preferences },
        setAutoRefreshEnabled: { _, _ in preferences },
        setTelemetryEnabled: { _, _ in preferences },
        updateDefaultSpeedLimits: { _, _ in preferences },
        observe: { _ in
            AsyncStream { continuation in
                Task {
                    await continuationBox.set(continuation)
                }
            }
        }
    )
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    func withValue(_ transform: (inout Value) -> Void) {
        lock.lock()
        transform(&storage)
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        let current = storage
        lock.unlock()
        return current
    }
}

private actor PreferencesContinuationBox {
    private var continuation: AsyncStream<UserPreferences>.Continuation?

    func set(_ continuation: AsyncStream<UserPreferences>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ preferences: UserPreferences) {
        continuation?.yield(preferences)
    }

    func finish() {
        continuation?.finish()
    }
}
