import Foundation
import Testing

@testable import Remission

@Suite("HTTP Warning Preferences Store Tests")
struct HttpWarningPreferencesStoreTests {
    // Проверяет in-memory store: set/read/reset.
    @Test
    func inMemorySetReadReset() async {
        let store = HttpWarningPreferencesStore.inMemory()
        let fingerprint = "fingerprint"

        #expect(await store.isSuppressed(fingerprint) == false)
        await store.setSuppressed(fingerprint, true)
        #expect(await store.isSuppressed(fingerprint))

        await store.reset(fingerprint)
        #expect(await store.isSuppressed(fingerprint) == false)
    }

    // Проверяет UserDefaults store на изолированном suite.
    @Test
    func userDefaultsSetReadReset() async {
        let suiteName = "HttpWarningPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = HttpWarningPreferencesStore.userDefaults(suiteName: suiteName)
        let fingerprint = "server-1"

        await store.setSuppressed(fingerprint, true)
        #expect(await store.isSuppressed(fingerprint))

        await store.reset(fingerprint)
        #expect(await store.isSuppressed(fingerprint) == false)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
