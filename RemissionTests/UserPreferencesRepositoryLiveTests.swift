import Foundation
import Testing

@testable import Remission

struct UserPreferencesRepositoryLiveTests {
    @Test
    func persistentRepositoryPersistsAndResetsWhenRequested() async throws {
        let suiteName = "userprefs-live-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Не удалось создать UserDefaults для suite \(suiteName)")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let updatedPreferences = try await repository.updateDefaultSpeedLimits(
            .init(
                downloadKilobytesPerSecond: 777,
                uploadKilobytesPerSecond: nil
            )
        )
        #expect(updatedPreferences.defaultSpeedLimits.downloadKilobytesPerSecond == 777)

        var pollingUpdated = updatedPreferences
        pollingUpdated = try await repository.updatePollingInterval(12)
        #expect(pollingUpdated.pollingInterval == 12)

        let rehydrated = try await UserPreferencesRepository.persistent(
            defaults: defaults
        ).load()
        #expect(rehydrated.pollingInterval == 12)
        #expect(rehydrated.defaultSpeedLimits.downloadKilobytesPerSecond == 777)

        let resetRepository = UserPreferencesRepository.persistent(
            defaults: defaults,
            resetStoredValue: true
        )
        let reset = try await resetRepository.load()
        #expect(reset == .default)
    }
}
