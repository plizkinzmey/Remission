import Foundation
import Testing

@testable import Remission

@Suite("HTTP Warning Preferences Store Tests")
struct HttpWarningPreferencesStoreTests {
    // Проверяет in-memory store: set/read/reset.
    @Test
    func inMemorySetReadReset() {
        let store = HttpWarningPreferencesStore.inMemory()
        let fingerprint = "fingerprint"

        #expect(store.isSuppressed(fingerprint) == false)
        store.setSuppressed(fingerprint, true)
        #expect(store.isSuppressed(fingerprint))

        store.reset(fingerprint)
        #expect(store.isSuppressed(fingerprint) == false)
    }

    // Проверяет UserDefaults store на изолированном suite.
    @Test
    func userDefaultsSetReadReset() {
        let suiteName = "HttpWarningPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = HttpWarningPreferencesStore.userDefaults(defaults: defaults)
        let fingerprint = "server-1"

        store.setSuppressed(fingerprint, true)
        #expect(store.isSuppressed(fingerprint))

        store.reset(fingerprint)
        #expect(store.isSuppressed(fingerprint) == false)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
