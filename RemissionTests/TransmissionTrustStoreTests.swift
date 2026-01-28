import Foundation
import Security
import Testing

@testable import Remission

@Suite("TransmissionTrustStore")
struct TransmissionTrustStoreTests {
    @Test("save -> load возвращает сохранённый fingerprint")
    func saveThenLoadFingerprint() throws {
        // Базовый happy-path хранилища отпечатков.
        let memory = KeychainInMemoryStore()
        let store = TransmissionTrustStore(interface: memory.makeTrustInterface())
        let identity = TransmissionServerTrustIdentity(
            host: "seedbox.local", port: 443, isSecure: true)
        let fingerprint = Data([0xAA, 0xBB, 0xCC])

        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)
        let loaded = try store.loadFingerprint(for: identity)

        #expect(loaded == fingerprint)
    }

    @Test("повторный save обновляет fingerprint при duplicate item")
    func duplicateSaveUpdatesFingerprint() throws {
        // Обновление отпечатка критично при ротации сертификата.
        let memory = KeychainInMemoryStore()
        let store = TransmissionTrustStore(interface: memory.makeTrustInterface())
        let identity = TransmissionServerTrustIdentity(
            host: "seedbox.local", port: 443, isSecure: true)

        try store.saveFingerprint(Data([0x01]), for: identity, metadata: nil)
        try store.saveFingerprint(Data([0x02, 0x03]), for: identity, metadata: nil)

        let loaded = try store.loadFingerprint(for: identity)
        #expect(loaded == Data([0x02, 0x03]))
    }

    @Test("delete не бросает ошибку при отсутствии записи")
    func deleteMissingDoesNotThrow() throws {
        // Это безопасное поведение для сценариев «сбросить доверие».
        let memory = KeychainInMemoryStore()
        let store = TransmissionTrustStore(interface: memory.makeTrustInterface())
        let identity = TransmissionServerTrustIdentity(
            host: "missing.local", port: 443, isSecure: true)

        try store.deleteFingerprint(for: identity)
    }

    @Test("load бросает unexpectedFingerprintEncoding при невалидном payload")
    func loadThrowsOnInvalidEncoding() {
        // Повреждённые данные должны приводить к явной ошибке, а не к ложному доверию.
        let badInterface = TransmissionTrustKeychainInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { _, result in
                if let result {
                    let invalid = Data([0xFF, 0xFE])
                    let payload: [String: Any] = [kSecValueData as String: invalid]
                    result.pointee = payload as CFDictionary
                }
                return errSecSuccess
            },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )
        let store = TransmissionTrustStore(interface: badInterface)
        let identity = TransmissionServerTrustIdentity(host: "bad.local", port: 443, isSecure: true)

        #expect(throws: TransmissionTrustStoreError.unexpectedFingerprintEncoding) {
            _ = try store.loadFingerprint(for: identity)
        }
    }
}
