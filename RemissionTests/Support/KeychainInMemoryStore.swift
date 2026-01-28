import Foundation
import Security

@testable import Remission

final class KeychainInMemoryStore: @unchecked Sendable {
    private struct Item {
        var valueData: Data
        var genericData: Data?
    }

    private var storage: [String: Item] = [:]
    private let lock = NSLock()

    func makeCredentialsInterface() -> KeychainItemInterface {
        KeychainItemInterface(
            add: { query, _ in
                self.add(query: query)
            },
            copyMatching: { query, result in
                self.copyMatching(query: query, result: result)
            },
            update: { query, attributes in
                self.update(query: query, attributes: attributes)
            },
            delete: { query in
                self.delete(query: query)
            }
        )
    }

    func makeTrustInterface() -> TransmissionTrustKeychainInterface {
        TransmissionTrustKeychainInterface(
            add: { query, _ in
                self.add(query: query)
            },
            copyMatching: { query, result in
                self.copyMatching(query: query, result: result)
            },
            update: { query, attributes in
                self.update(query: query, attributes: attributes)
            },
            delete: { query in
                self.delete(query: query)
            }
        )
    }

    private func add(query: CFDictionary) -> OSStatus {
        guard let account = account(from: query), let valueData = valueData(from: query) else {
            return errSecParam
        }

        lock.lock()
        defer { lock.unlock() }

        guard storage[account] == nil else {
            return errSecDuplicateItem
        }

        storage[account] = Item(valueData: valueData, genericData: genericData(from: query))
        return errSecSuccess
    }

    private func copyMatching(query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?)
        -> OSStatus
    {
        guard let account = account(from: query) else {
            return errSecParam
        }

        lock.lock()
        let item = storage[account]
        lock.unlock()

        guard let item else {
            return errSecItemNotFound
        }

        if let result {
            var payload: [String: Any] = [
                kSecValueData as String: item.valueData
            ]
            if let genericData = item.genericData {
                payload[kSecAttrGeneric as String] = genericData
            }
            result.pointee = payload as CFDictionary
        }

        return errSecSuccess
    }

    private func update(query: CFDictionary, attributes: CFDictionary) -> OSStatus {
        guard let account = account(from: query), let valueData = valueData(from: attributes) else {
            return errSecParam
        }

        lock.lock()
        defer { lock.unlock() }

        guard storage[account] != nil else {
            return errSecItemNotFound
        }

        storage[account] = Item(valueData: valueData, genericData: genericData(from: attributes))
        return errSecSuccess
    }

    private func delete(query: CFDictionary) -> OSStatus {
        guard let account = account(from: query) else {
            return errSecParam
        }

        lock.lock()
        defer { lock.unlock() }

        guard storage.removeValue(forKey: account) != nil else {
            return errSecItemNotFound
        }

        return errSecSuccess
    }

    private func account(from query: CFDictionary) -> String? {
        (query as NSDictionary)[kSecAttrAccount as String] as? String
    }

    private func valueData(from query: CFDictionary) -> Data? {
        (query as NSDictionary)[kSecValueData as String] as? Data
    }

    private func genericData(from query: CFDictionary) -> Data? {
        (query as NSDictionary)[kSecAttrGeneric as String] as? Data
    }
}
