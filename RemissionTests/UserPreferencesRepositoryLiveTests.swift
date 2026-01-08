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

        let serverID = UUID()
        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let updatedPreferences = try await repository.updateDefaultSpeedLimits(
            serverID: serverID,
            .init(
                downloadKilobytesPerSecond: 777,
                uploadKilobytesPerSecond: nil
            )
        )
        #expect(updatedPreferences.defaultSpeedLimits.downloadKilobytesPerSecond == 777)

        var pollingUpdated = updatedPreferences
        pollingUpdated = try await repository.updatePollingInterval(
            serverID: serverID,
            12
        )
        #expect(pollingUpdated.pollingInterval == 12)

        let rehydrated = try await UserPreferencesRepository.persistent(
            defaults: defaults
        ).load(serverID: serverID)
        #expect(rehydrated.pollingInterval == 12)
        #expect(rehydrated.defaultSpeedLimits.downloadKilobytesPerSecond == 777)

        let resetRepository = UserPreferencesRepository.persistent(
            defaults: defaults,
            resetStoredValue: true
        )
        let reset = try await resetRepository.load(serverID: serverID)
        #expect(reset == .default)
    }

    @Test
    func migrationAddsTelemetryFlagWithDefaultFalse() async throws {
        struct LegacyPreferencesV1: Codable {
            var version: Int
            var pollingInterval: TimeInterval
            var isAutoRefreshEnabled: Bool
            var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits
        }

        let suiteName = "userprefs-migration-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Не удалось создать UserDefaults для suite \(suiteName)")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy = LegacyPreferencesV1(
            version: 1,
            pollingInterval: 9,
            isAutoRefreshEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: 128,
                uploadKilobytesPerSecond: 256
            )
        )
        let encoded = try JSONEncoder().encode(legacy)
        defaults.set(encoded, forKey: "user_preferences")

        let serverID = UUID()
        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let migrated = try await repository.load(serverID: serverID)

        #expect(migrated.version == UserPreferences.currentVersion)
        #expect(migrated.isTelemetryEnabled == false)
        #expect(migrated.pollingInterval == 9)
        #expect(migrated.defaultSpeedLimits.uploadKilobytesPerSecond == 256)

        if let raw = defaults.data(forKey: "user_preferences_by_server") {
            let decoded = try JSONDecoder().decode([String: UserPreferences].self, from: raw)
            #expect(decoded[serverID.uuidString]?.isTelemetryEnabled == false)
            #expect(decoded[serverID.uuidString]?.version == UserPreferences.currentVersion)
        } else {
            Issue.record("Снапшот преференсов отсутствует после миграции")
        }
    }

    @Test
    func telemetryFlagPersistsAcrossLoads() async throws {
        let suiteName = "userprefs-telemetry-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Не удалось создать UserDefaults для suite \(suiteName)")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let serverID = UUID()
        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let updated = try await repository.setTelemetryEnabled(
            serverID: serverID,
            true
        )

        #expect(updated.isTelemetryEnabled == true)

        let rehydrated = try await UserPreferencesRepository.persistent(
            defaults: defaults
        ).load(serverID: serverID)

        #expect(rehydrated.isTelemetryEnabled == true)
        #expect(rehydrated.version == UserPreferences.currentVersion)
    }
}
