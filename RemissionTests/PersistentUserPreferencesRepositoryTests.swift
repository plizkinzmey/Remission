import Foundation
import Testing

@testable import Remission

@Suite("PersistentUserPreferencesRepository")
struct PersistentUserPreferencesRepositoryTests {

    @Test("Persists changes to UserDefaults")
    func persistAndReload() async throws {
        let suiteName = "test-suite-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let serverID = UUID()

        // Initial load
        let initial = try await repository.load(serverID: serverID)
        #expect(initial.version == UserPreferences.currentVersion)

        // Update
        _ = try await repository.updatePollingInterval(serverID: serverID, 12.0)

        // Reload with new repository instance to check persistence
        // Note: PersistentUserPreferencesStore loads snapshot in init
        let repo2 = UserPreferencesRepository.persistent(defaults: defaults)
        let loaded = try await repo2.load(serverID: serverID)

        #expect(loaded.pollingInterval == 12.0)
    }

    @Test("Separate preferences for different servers")
    func separateServerPreferences() async throws {
        let suiteName = "test-suite-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let server1 = UUID()
        let server2 = UUID()

        _ = try await repository.updatePollingInterval(serverID: server1, 10.0)
        _ = try await repository.updatePollingInterval(serverID: server2, 20.0)

        let pref1 = try await repository.load(serverID: server1)
        let pref2 = try await repository.load(serverID: server2)

        #expect(pref1.pollingInterval == 10.0)
        #expect(pref2.pollingInterval == 20.0)
    }

    @Test("Legacy migration")
    func legacyMigration() async throws {
        let suiteName = "test-suite-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Write legacy preference manually
        // We need to match UserPreferences struct structure for encoding
        // Assuming UserPreferences has public init or we can use a similar struct
        let legacy = UserPreferences(
            pollingInterval: 99.0,
            isAutoRefreshEnabled: true,
            isTelemetryEnabled: false,
            defaultSpeedLimits: .init(downloadKilobytesPerSecond: 0, uploadKilobytesPerSecond: 0),
            recentDownloadDirectories: [],
            version: 1
        )

        if let data = try? JSONEncoder().encode(legacy) {
            // Legacy key from PersistentUserPreferencesStore
            defaults.set(data, forKey: "user_preferences")
        }

        let repository = UserPreferencesRepository.persistent(defaults: defaults)
        let serverID = UUID()

        // Load should migrate legacy to server specific if no server specific exists
        let loaded = try await repository.load(serverID: serverID)

        #expect(loaded.pollingInterval == 99.0)
    }
}
