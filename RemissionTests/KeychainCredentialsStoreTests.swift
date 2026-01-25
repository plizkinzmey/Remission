import Foundation
import Security
import Testing

@testable import Remission

@Suite("KeychainCredentialsStore")
struct KeychainCredentialsStoreTests {
    @Test("save -> load возвращает те же credentials")
    func saveThenLoadReturnsCredentials() throws {
        // Базовый контракт: запись в Keychain должна быть читаема без потерь.
        let memory = KeychainInMemoryStore()
        let store = KeychainCredentialsStore(interface: memory.makeCredentialsInterface())
        let key = TransmissionServerCredentialsKey(
            host: "nas.local", port: 9091, isSecure: false, username: "alice")
        let credentials = TransmissionServerCredentials(key: key, password: "secret")

        try store.save(credentials)
        let loaded = try store.load(key: key)

        #expect(loaded == credentials)
    }

    @Test("повторный save обновляет пароль через errSecDuplicateItem -> update")
    func duplicateSaveUpdatesPassword() throws {
        // Важно, чтобы обновление не требовало предварительного delete.
        let memory = KeychainInMemoryStore()
        let store = KeychainCredentialsStore(interface: memory.makeCredentialsInterface())
        let key = TransmissionServerCredentialsKey(
            host: "nas.local", port: 9091, isSecure: false, username: "alice")

        try store.save(.init(key: key, password: "old"))
        try store.save(.init(key: key, password: "new"))

        let loaded = try store.load(key: key)
        #expect(loaded?.password == "new")
    }

    @Test("delete не бросает ошибку при отсутствии записи")
    func deleteMissingDoesNotThrow() throws {
        // Отсутствие credentials — штатная ситуация (например, после logout).
        let memory = KeychainInMemoryStore()
        let store = KeychainCredentialsStore(interface: memory.makeCredentialsInterface())
        let key = TransmissionServerCredentialsKey(
            host: "missing.local", port: 9091, isSecure: false, username: "ghost")

        try store.delete(key: key)
    }

    @Test("load бросает unexpectedItemData при невалидном payload")
    func loadThrowsOnInvalidPayload() {
        // Защищаемся от повреждённых записей в Keychain.
        let badInterface = KeychainItemInterface(
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
        let store = KeychainCredentialsStore(interface: badInterface)
        let key = TransmissionServerCredentialsKey(
            host: "bad.local", port: 9091, isSecure: false, username: "alice")

        #expect(throws: KeychainCredentialsStoreError.unexpectedItemData) {
            _ = try store.load(key: key)
        }
    }
}
