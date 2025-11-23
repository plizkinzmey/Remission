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
        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State()
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
        let intervalRecorder = LockedValue<[Double]>([])
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { interval in
                intervalRecorder.withValue { $0.append(interval) }
                var updated = preferences
                updated.pollingInterval = interval
                await continuationBox.yield(updated)
                return updated
            },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(isLoading: false)
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
        let limitsRecorder = LockedValue<[UserPreferences.DefaultSpeedLimits]>([])

        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { limits in
                limitsRecorder.withValue { $0.append(limits) }
                var updated = preferences
                updated.defaultSpeedLimits = limits
                return updated
            },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        var initialState = SettingsReducer.State(isLoading: false)
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
        let toggleRecorder = LockedValue<[Bool]>([])
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { isEnabled in
                toggleRecorder.withValue { $0.append(isEnabled) }
                var updated = preferences
                updated.isTelemetryEnabled = isEnabled
                await continuationBox.yield(updated)
                return updated
            },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State(isLoading: false)
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
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State()
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
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "ошибка" }
        }

        let repository = UserPreferencesRepository(
            load: { throw DummyError.failed },
            updatePollingInterval: { _ in throw DummyError.failed },
            setAutoRefreshEnabled: { _ in throw DummyError.failed },
            setTelemetryEnabled: { _ in throw DummyError.failed },
            updateDefaultSpeedLimits: { _ in throw DummyError.failed },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        let store = TestStore(
            initialState: SettingsReducer.State()
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
                TextState("Не удалось сохранить настройки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Закрыть")
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

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences),
            preferencesStore: preferencesStore
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

        let persisted = await preferencesStore.preferences
        #expect(persisted.defaultSpeedLimits == expected.defaultSpeedLimits)
    }

    @Test("ошибка сохранения телеметрии откатывает состояние")
    func telemetryToggleFailureRollsBackState() async {
        var preferences = DomainFixtures.userPreferences
        preferences.isTelemetryEnabled = true
        let preferencesStore = DomainFixtures.makeUserPreferencesStore(preferences: preferences)
        await preferencesStore.markFailure(.setTelemetryEnabled)

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences),
            preferencesStore: preferencesStore
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
                TextState("Не удалось сохранить настройки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Закрыть")
                }
            } message: {
                TextState(expectedError.errorDescription ?? "")
            }
        }

        let persisted = await preferencesStore.preferences
        #expect(persisted.isTelemetryEnabled == true)
    }

    @Test("ошибка сохранения откатывает состояние и показывает alert")
    func saveFailureRollsBackState() async {
        let preferences = DomainFixtures.userPreferences
        let preferencesStore = DomainFixtures.makeUserPreferencesStore(preferences: preferences)
        await preferencesStore.markFailure(.updatePollingInterval)

        let store = TestStoreFactory.makeSettingsTestStore(
            initialState: loadedState(from: preferences),
            preferencesStore: preferencesStore
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
                TextState("Не удалось сохранить настройки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Закрыть")
                }
            } message: {
                TextState(expectedError.errorDescription ?? "")
            }
        }

        let persisted = await preferencesStore.preferences
        #expect(persisted.pollingInterval == preferences.pollingInterval)
    }
}

private func loadedState(from preferences: UserPreferences) -> SettingsReducer.State {
    var state = SettingsReducer.State(
        isLoading: false,
        pollingIntervalSeconds: preferences.pollingInterval,
        isAutoRefreshEnabled: preferences.isAutoRefreshEnabled,
        isTelemetryEnabled: preferences.isTelemetryEnabled,
        defaultSpeedLimits: preferences.defaultSpeedLimits
    )
    state.persistedPreferences = preferences
    return state
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
