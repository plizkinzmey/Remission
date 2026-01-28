import Foundation
import Testing

@testable import Remission

@Suite("User Preferences Tests")
struct UserPreferencesTests {
    // Проверяет декодирование старой схемы без version/isTelemetryEnabled/recentDownloadDirectories.
    @Test
    func decodingMissingFieldsUsesSafeDefaults() throws {
        let json = [
            "{",
            #"  "pollingInterval": 5,"#,
            #"  "isAutoRefreshEnabled": true,"#,
            #"  "defaultSpeedLimits": {"#,
            #"    "downloadKilobytesPerSecond": null,"#,
            #"    "uploadKilobytesPerSecond": null"#,
            "  }",
            "}"
        ].joined(separator: "\n")

        let preferences = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        #expect(preferences.version == UserPreferences.currentVersion)
        #expect(preferences.isTelemetryEnabled == false)
        #expect(preferences.recentDownloadDirectories.isEmpty)
    }

    // Проверяет миграцию к актуальной версии схемы.
    @Test
    func migrationUpdatesVersionAndResetsNewFields() {
        let old = UserPreferences(
            pollingInterval: 10,
            isAutoRefreshEnabled: false,
            isTelemetryEnabled: true,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: 100,
                uploadKilobytesPerSecond: 50
            ),
            recentDownloadDirectories: ["/downloads"],
            version: 1
        )

        let migrated = UserPreferences.migratedToCurrentVersion(old)
        #expect(migrated.version == UserPreferences.currentVersion)
        #expect(migrated.isTelemetryEnabled == false)
        #expect(migrated.recentDownloadDirectories.isEmpty)
        #expect(migrated.pollingInterval == old.pollingInterval)
    }

    // Проверяет, что default использует актуальную версию.
    @Test
    func defaultUsesCurrentVersion() {
        #expect(UserPreferences.default.version == UserPreferences.currentVersion)
    }
}
