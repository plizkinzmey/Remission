import Foundation
import Testing

@testable import Remission

@Suite("UserPreferences migration")
struct UserPreferencesMigrationTests {
    @Test("Декод legacy v1 устанавливает телеметрию в false и поднимает версию")
    func decodeLegacyV1SetsTelemetryDisabled() throws {
        struct LegacyPreferencesV1: Codable {
            var version: Int
            var pollingInterval: TimeInterval
            var isAutoRefreshEnabled: Bool
            var defaultSpeedLimits: UserPreferences.DefaultSpeedLimits
        }

        let legacy = LegacyPreferencesV1(
            version: 1,
            pollingInterval: 9,
            isAutoRefreshEnabled: true,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: 128,
                uploadKilobytesPerSecond: 256
            )
        )
        let encoded = try JSONEncoder().encode(legacy)

        let decoded = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        let migrated = UserPreferences.migratedToCurrentVersion(decoded)

        #expect(migrated.isTelemetryEnabled == false)
        #expect(migrated.version == UserPreferences.currentVersion)
        #expect(migrated.pollingInterval == 9)
        #expect(migrated.defaultSpeedLimits.uploadKilobytesPerSecond == 256)
    }
}
