import Foundation
import Testing

@testable import Remission

@Suite("InMemoryUserPreferencesRepository")
struct InMemoryUserPreferencesRepositoryTests {
    @Test("load возвращает мигрированные настройки и updatePollingInterval применяет изменения")
    func loadAndUpdatePollingInterval() async throws {
        // Проверяем миграцию версии и базовый update-flow.
        var legacy = UserPreferences.default
        legacy.version = 1
        legacy.isTelemetryEnabled = true
        legacy.recentDownloadDirectories = ["/should-reset"]

        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(preferences: legacy, serverID: serverID)
        let repository = UserPreferencesRepository.inMemory(store: store)

        let loaded = try await repository.load(serverID: serverID)
        #expect(loaded.version == UserPreferences.currentVersion)
        #expect(loaded.isTelemetryEnabled == false)
        #expect(loaded.recentDownloadDirectories.isEmpty)

        let updated = try await repository.updatePollingInterval(serverID: serverID, 15)
        #expect(updated.pollingInterval == 15)
        #expect(updated.version == UserPreferences.currentVersion)
    }

    @Test("observe получает обновления после updateDefaultSpeedLimits")
    func observeReceivesUpdates() async throws {
        // Здесь важно убедиться, что observer-механизм реально работает.
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: .default, serverID: serverID)
        let repository = UserPreferencesRepository.inMemory(store: store)

        let stream = repository.observe(serverID: serverID)
        let observedBox = ObservedPreferencesBox()
        let observationTask = Task {
            for await preferences in stream {
                await observedBox.set(preferences)
                break
            }
        }
        defer { observationTask.cancel() }

        // Даём времени подписке зарегистрироваться внутри actor.
        await Task.yield()
        await Task.yield()

        let limits = UserPreferences.DefaultSpeedLimits(
            downloadKilobytesPerSecond: 100, uploadKilobytesPerSecond: 50)
        _ = try await repository.updateDefaultSpeedLimits(serverID: serverID, limits)

        let observed = try await waitForObserved(from: observedBox)
        #expect(observed?.defaultSpeedLimits == limits)
    }

    @Test(
        "updateRecentDownloadDirectories бросает operationFailed, когда операция помечена как failing"
    )
    func updateFailureIsPropagated() async {
        // Error-path для UI и редьюсеров.
        let serverID = UUID()
        let store = InMemoryUserPreferencesRepositoryStore(
            preferences: .default, serverID: serverID)
        let repository = UserPreferencesRepository.inMemory(store: store)

        await store.markFailure(.updateRecentDownloadDirectories)

        do {
            _ = try await repository.updateRecentDownloadDirectories(
                serverID: serverID,
                ["/downloads"]
            )
            Issue.record("Ожидали ошибку updateRecentDownloadDirectories, но она не была брошена")
        } catch let error as InMemoryUserPreferencesRepositoryError {
            #expect(error == .operationFailed(.updateRecentDownloadDirectories))
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}

private func waitForObserved(
    from box: ObservedPreferencesBox,
    attempts: Int = 20,
    delay: Duration = .milliseconds(25)
) async throws -> UserPreferences? {
    for _ in 0..<attempts {
        if let value = await box.get() {
            return value
        }
        try await Task.sleep(for: delay)
    }

    Issue.record("Не дождались значения из observe(stream)")
    return nil
}

private actor ObservedPreferencesBox {
    private var value: UserPreferences?

    func set(_ value: UserPreferences) {
        self.value = value
    }

    func get() -> UserPreferences? {
        value
    }
}
