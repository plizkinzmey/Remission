import Foundation
import Testing

@testable import Remission

@Suite("TransmissionTrustStoreClient")
struct TransmissionTrustStoreClientTests {
    @Test("placeholder deleteFingerprint не делает ничего и не бросает ошибок")
    func placeholderIsNoop() throws {
        // Это важно для превью и тестовых окружений без Keychain.
        let identity = TransmissionServerTrustIdentity(
            host: "example.com", port: 443, isSecure: true)
        try TransmissionTrustStoreClient.placeholder.deleteFingerprint(identity)
    }

    @Test("live(deleteFingerprint:) делегирует удаление в store")
    func liveDelegatesToStore() throws {
        // Проверяем wiring: клиент должен реально удалять сохранённый отпечаток.
        let memory = KeychainInMemoryStore()
        let store = TransmissionTrustStore(interface: memory.makeTrustInterface())
        let client = TransmissionTrustStoreClient.live(store: store)
        let identity = TransmissionServerTrustIdentity(
            host: "seedbox.local", port: 443, isSecure: true)
        let fingerprint = Data([0xAA, 0xBB])

        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)
        #expect(try store.loadFingerprint(for: identity) == fingerprint)

        try client.deleteFingerprint(identity)
        #expect(try store.loadFingerprint(for: identity) == nil)
    }
}
