import Foundation
import Security
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface
@Suite("KeychainCredentialsStore")
struct KeychainCredentialsStoreTests {
    @Test("Save inserts new record with expected attributes")
    func saveInsertsNewItem() throws {
        let key = sampleKey()
        let capturedQuery = LockedBox<[String: Any]?>(nil)

        let interface = KeychainItemInterface(
            add: { query, _ in
                capturedQuery.set(query as NSDictionary as? [String: Any])
                return errSecSuccess
            },
            copyMatching: { _, _ in errSecItemNotFound },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)
        let credentials = TransmissionServerCredentials(key: key, password: "super-secret")
        try store.save(credentials)

        guard let query = capturedQuery.value else {
            Issue.record("Запрос SecItemAdd не был зафиксирован.")
            return
        }

        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == "com.remission.transmission")
        #expect(query[kSecAttrAccount as String] as? String == key.accountIdentifier)
        #expect(
            query[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlocked
                as String)
        #if os(macOS)
            #expect(query[kSecUseDataProtectionKeychain as String] == nil)
        #else
            #expect(boolValue(query[kSecUseDataProtectionKeychain as String]) == true)
        #endif
        #expect(boolValue(query[kSecAttrSynchronizable as String]) == false)

        let storedPassword = query[kSecValueData as String] as? Data
        #expect(storedPassword == Data("super-secret".utf8))

        let metadataData = query[kSecAttrGeneric as String] as? Data
        let metadata = metadataData.flatMap {
            try? JSONDecoder().decode(TestMetadata.self, from: $0)
        }
        #expect(metadata?.host == key.host)
        #expect(metadata?.port == key.port)
        #expect(metadata?.isSecure == key.isSecure)
        #expect(metadata?.username == key.username)
    }

    @Test("Save updates existing record when duplicate detected")
    func saveUpdatesExistingItem() throws {
        let key = sampleKey()
        let credentials = TransmissionServerCredentials(key: key, password: "new-secret")
        let updateQuery = LockedBox<[String: Any]?>(nil)
        let updateAttributes = LockedBox<[String: Any]?>(nil)

        let interface = KeychainItemInterface(
            add: { _, _ in errSecDuplicateItem },
            copyMatching: { _, _ in errSecItemNotFound },
            update: { query, attributes in
                updateQuery.set(query as NSDictionary as? [String: Any])
                updateAttributes.set(attributes as NSDictionary as? [String: Any])
                return errSecSuccess
            },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)
        try store.save(credentials)

        let persistedQuery = updateQuery.value
        let persistedAttributes = updateAttributes.value

        #expect(persistedQuery?[kSecAttrAccount as String] as? String == key.accountIdentifier)
        #expect(
            persistedAttributes?[kSecValueData as String] as? Data
                == Data("new-secret".utf8)
        )

        let metadataData = persistedAttributes?[kSecAttrGeneric as String] as? Data
        let metadata = metadataData.flatMap {
            try? JSONDecoder().decode(TestMetadata.self, from: $0)
        }
        #expect(metadata?.host == key.host)
        #expect(metadata?.port == key.port)
        #expect(metadata?.isSecure == key.isSecure)
        #expect(metadata?.username == key.username)
    }

    @Test("Save propagates update failure")
    func savePropagatesUpdateFailure() {
        let key = sampleKey()
        let credentials = TransmissionServerCredentials(key: key, password: "value")

        let interface = KeychainItemInterface(
            add: { _, _ in errSecDuplicateItem },
            copyMatching: { _, _ in errSecItemNotFound },
            update: { _, _ in errSecInteractionNotAllowed },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)

        #expect(throws: KeychainCredentialsStoreError.osStatus(errSecInteractionNotAllowed)) {
            try store.save(credentials)
        }
    }

    @Test("Load returns credentials with metadata")
    func loadReturnsCredentials() throws {
        let key = sampleKey()
        let passwordData = Data("keepme".utf8)
        let metadataData = try JSONEncoder().encode(TestMetadata(from: key))
        let capturedQuery = LockedBox<[String: Any]?>(nil)

        let interface = KeychainItemInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { query, result in
                capturedQuery.set(query as NSDictionary as? [String: Any])
                let item: [String: Any] = [
                    kSecValueData as String: passwordData,
                    kSecAttrGeneric as String: metadataData
                ]
                result?.pointee = item as CFDictionary
                return errSecSuccess
            },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)
        let loaded = try store.load(key: key)

        let query = capturedQuery.value
        #expect(query?[kSecAttrAccount as String] as? String == key.accountIdentifier)
        #expect(boolValue(query?[kSecReturnData as String]) == true)
        #expect(boolValue(query?[kSecReturnAttributes as String]) == true)
        #expect(query?[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)

        #expect(loaded?.password == "keepme")
        #expect(loaded?.key == key)
    }

    @Test("Load returns nil when item is missing")
    func loadReturnsNilWhenMissing() throws {
        let key = sampleKey()
        let interface = KeychainItemInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { _, _ in errSecItemNotFound },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)
        let result = try store.load(key: key)
        #expect(result == nil)
    }

    @Test("Load throws on invalid data payload")
    func loadThrowsOnInvalidData() {
        let key = sampleKey()
        let interface = KeychainItemInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { _, result in
                let item: [String: Any] = [
                    kSecAttrGeneric as String: Data()
                ]
                result?.pointee = item as CFDictionary
                return errSecSuccess
            },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )

        let store = KeychainCredentialsStore(interface: interface)
        #expect(throws: KeychainCredentialsStoreError.unexpectedItemData) {
            _ = try store.load(key: key)
        }
    }

    @Test("Delete removes record")
    func deleteRemovesRecord() throws {
        let key = sampleKey()
        let capturedQuery = LockedBox<[String: Any]?>(nil)

        let interface = KeychainItemInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { _, _ in errSecSuccess },
            update: { _, _ in errSecSuccess },
            delete: { query in
                capturedQuery.set(query as NSDictionary as? [String: Any])
                return errSecSuccess
            }
        )

        let store = KeychainCredentialsStore(interface: interface)
        try store.delete(key: key)

        #expect(capturedQuery.value?[kSecAttrAccount as String] as? String == key.accountIdentifier)
        #expect(
            capturedQuery.value?[kSecAttrService as String] as? String
                == "com.remission.transmission")
    }

    @Test("Delete ignores missing record")
    func deleteIgnoresMissingRecord() throws {
        let key = sampleKey()
        let interface = KeychainItemInterface(
            add: { _, _ in errSecSuccess },
            copyMatching: { _, _ in errSecSuccess },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecItemNotFound }
        )

        let store = KeychainCredentialsStore(interface: interface)
        try store.delete(key: key)
    }
}

// MARK: - Helpers

private func sampleKey() -> TransmissionServerCredentialsKey {
    TransmissionServerCredentialsKey(
        host: "nas.local", port: 9091, isSecure: false, username: "admin")
}

private func boolValue(_ value: Any?) -> Bool? {
    switch value {
    case let bool as Bool:
        return bool
    case let number as NSNumber:
        return number.boolValue
    default:
        return nil
    }
}

private struct TestMetadata: Codable, Equatable {
    var host: String
    var port: Int
    var isSecure: Bool
    var username: String

    init(host: String, port: Int, isSecure: Bool, username: String) {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.username = username
    }

    init(from key: TransmissionServerCredentialsKey) {
        self.init(host: key.host, port: key.port, isSecure: key.isSecure, username: key.username)
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private var valueStorage: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.valueStorage = value
    }

    func set(_ newValue: Value) {
        lock.lock()
        valueStorage = newValue
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return valueStorage
    }
}
// swiftlint:enable explicit_type_interface
