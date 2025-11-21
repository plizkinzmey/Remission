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
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
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
        }

        #expect(limitsRecorder.value == [downloadOnly, bothLimits])
    }

    @Test("observe поток обновляет состояние")
    func observeStreamUpdatesState() async {
        let preferences = DomainFixtures.userPreferences
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
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
            $0.defaultSpeedLimits = preferences.defaultSpeedLimits
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
            $0.defaultSpeedLimits = updated.defaultSpeedLimits
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
