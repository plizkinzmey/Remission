import Foundation
import Testing

@testable import Remission

@Suite("TransmissionTrustStore Tests")
struct TransmissionTrustStoreTests {
    private let identity = TransmissionServerTrustIdentity(
        host: "example.com",
        port: 443,
        isSecure: true
    )

    @Test("saveFingerprint stores and loadFingerprint returns value")
    func testSaveAndLoadFingerprint() throws {
        let store = TransmissionTrustStore.inMemory()
        let fingerprint = Data(repeating: 0xAB, count: 32)

        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)
        let loaded = try store.loadFingerprint(for: identity)

        #expect(loaded == fingerprint)
    }

    @Test("saveFingerprint updates existing entry")
    func testUpdateFingerprint() throws {
        let store = TransmissionTrustStore.inMemory()
        let initial = Data(repeating: 0xCD, count: 32)
        let updated = Data(repeating: 0xEF, count: 32)

        try store.saveFingerprint(initial, for: identity, metadata: nil)
        try store.saveFingerprint(updated, for: identity, metadata: nil)

        let loaded = try store.loadFingerprint(for: identity)
        #expect(loaded == updated)
    }

    @Test("deleteFingerprint removes stored value")
    func testDeleteFingerprint() throws {
        let store = TransmissionTrustStore.inMemory()
        let fingerprint = Data(repeating: 0x01, count: 32)

        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)
        try store.deleteFingerprint(for: identity)

        let loaded = try store.loadFingerprint(for: identity)
        #expect(loaded == nil)
    }
}
