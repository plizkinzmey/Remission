import CryptoKit
import Foundation
import Security

/// Ошибки хранилища отпечатков TLS сертификатов.
enum TransmissionTrustStoreError: Error, Equatable, Sendable {
    case unexpectedFingerprintEncoding
    case notFound
    case osStatus(OSStatus)
}

extension TransmissionTrustStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unexpectedFingerprintEncoding:
            return "Не удалось закодировать отпечаток сертификата."
        case .notFound:
            return "Сохранённый отпечаток не найден."
        case .osStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "OSStatus \(status)"
        }
    }
}

/// Интерфейс функций Keychain, необходимый для работы trust-store (для тестируемости).
struct TransmissionTrustKeychainInterface: Sendable {
    var add: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    var copyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    var update: @Sendable (CFDictionary, CFDictionary) -> OSStatus
    var delete: @Sendable (CFDictionary) -> OSStatus

    static let live: Self = Self(
        add: { SecItemAdd($0, $1) },
        copyMatching: { SecItemCopyMatching($0, $1) },
        update: { SecItemUpdate($0, $1) },
        delete: { SecItemDelete($0) }
    )
}

/// Metadata structure saved alongside the fingerprint.
private struct TransmissionTrustMetadata: Codable, Equatable {
    var host: String
    var port: Int
    var isSecure: Bool
    var commonName: String?
    var organization: String?
    var storedAt: Date
}

/// Хранилище отпечатков TLS сертификатов Transmission.
public struct TransmissionTrustStore: Sendable {
    private enum Constants {
        static let serviceIdentifier: String = "com.remission.transmission.trust"
    }

    private let interface: TransmissionTrustKeychainInterface

    public init() {
        self.interface = .live
    }

    init(interface: TransmissionTrustKeychainInterface) {
        self.interface = interface
    }

    /// Сохраняет отпечаток SHA-256 для конкретного сервера.
    func saveFingerprint(
        _ fingerprint: Data,
        for identity: TransmissionServerTrustIdentity,
        metadata: TransmissionCertificateInfo?
    ) throws {
        let (passwordData, metadataData) = try encodePayload(
            fingerprint: fingerprint,
            identity: identity,
            metadata: metadata
        )

        var addQuery: [String: Any] = baseQuery(for: identity)
        addQuery[kSecValueData as String] = passwordData
        addQuery[kSecAttrGeneric as String] = metadataData

        let status: OSStatus = interface.add(addQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try updateFingerprint(
                fingerprint,
                for: identity,
                metadata: metadata,
                passwordData: passwordData,
                metadataData: metadataData
            )
        default:
            throw mapStatus(status)
        }
    }

    /// Возвращает сохранённый отпечаток (или nil, если отсутствует).
    func loadFingerprint(for identity: TransmissionServerTrustIdentity) throws -> Data? {
        var query: [String: Any] = baseQuery(for: identity)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status: OSStatus = interface.copyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard
                let item = result as? [String: Any],
                let fingerprintPayload = item[kSecValueData as String] as? Data,
                let encodedFingerprint = String(data: fingerprintPayload, encoding: .utf8),
                let fingerprintData = Data(base64Encoded: encodedFingerprint)
            else {
                throw TransmissionTrustStoreError.unexpectedFingerprintEncoding
            }
            return fingerprintData

        case errSecItemNotFound:
            return nil
        default:
            throw mapStatus(status)
        }
    }

    /// Удаляет сохранённый отпечаток. Отсутствие записи не считается ошибкой.
    func deleteFingerprint(for identity: TransmissionServerTrustIdentity) throws {
        let query: [String: Any] = baseQuery(for: identity)
        let status: OSStatus = interface.delete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw mapStatus(status)
        }
    }

    // MARK: - Helpers

    private func updateFingerprint(
        _ fingerprint: Data,
        for identity: TransmissionServerTrustIdentity,
        metadata: TransmissionCertificateInfo?,
        passwordData: Data,
        metadataData: Data
    ) throws {
        let query: [String: Any] = baseQuery(for: identity)
        let attributes: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrGeneric as String: metadataData
        ]

        let status: OSStatus = interface.update(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw mapStatus(status)
        }
    }

    private func encodePayload(
        fingerprint: Data,
        identity: TransmissionServerTrustIdentity,
        metadata: TransmissionCertificateInfo?
    ) throws -> (Data, Data) {
        let fingerprintString: String = fingerprint.base64EncodedString()
        guard let data = fingerprintString.data(using: .utf8) else {
            throw TransmissionTrustStoreError.unexpectedFingerprintEncoding
        }

        let meta = TransmissionTrustMetadata(
            host: identity.host,
            port: identity.port,
            isSecure: identity.isSecure,
            commonName: metadata?.commonName,
            organization: metadata?.organization,
            storedAt: Date()
        )

        let metaData: Data = try JSONEncoder().encode(meta)
        return (data, metaData)
    }

    private func baseQuery(for identity: TransmissionServerTrustIdentity) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.serviceIdentifier,
            kSecAttrAccount as String: identity.canonicalIdentifier,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: kCFBooleanFalse as CFBoolean
        ]
        #if !os(macOS)
            // Data protection keychain требует соответствующих entitlements; на macOS может вернуть errSecMissingEntitlement.
            query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    private func mapStatus(_ status: OSStatus) -> TransmissionTrustStoreError {
        switch status {
        case errSecItemNotFound:
            return .notFound
        default:
            return .osStatus(status)
        }
    }
}

// MARK: - Fingerprint helpers

/// Utility for computing SHA-256 fingerprints from certificates.
enum TransmissionCertificateFingerprint {
    static func fingerprintSHA256(for trust: SecTrust) throws -> Data {
        guard
            let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let certificate = certificates.first
        else {
            throw TransmissionTrustStoreError.unexpectedFingerprintEncoding
        }
        let certificateData: Data = SecCertificateCopyData(certificate) as Data
        let hash: SHA256.Digest = SHA256.hash(data: certificateData)
        return Data(hash)
    }
}

#if DEBUG
    private final class TransmissionTrustInMemoryDatabase: @unchecked Sendable {
        // Safety invariant:
        // - Access to `storage` is fully synchronized with `NSLock`.
        // - Stored values are `Data` blobs; no external mutation occurs after insertion.
        private var storage: [String: (value: Data, generic: Data)] = [:]
        private let lock: NSLock = NSLock()

        func add(account: String, value: Data, generic: Data) -> OSStatus {
            lock.lock()
            defer { lock.unlock() }
            guard storage[account] == nil else {
                return errSecDuplicateItem
            }
            storage[account] = (value, generic)
            return errSecSuccess
        }

        func copy(account: String) -> (value: Data, generic: Data)? {
            lock.lock()
            defer { lock.unlock() }
            return storage[account]
        }

        func update(account: String, value: Data, generic: Data) -> OSStatus {
            lock.lock()
            defer { lock.unlock() }
            guard storage[account] != nil else {
                return errSecItemNotFound
            }
            storage[account] = (value, generic)
            return errSecSuccess
        }

        func delete(account: String) -> OSStatus {
            lock.lock()
            defer { lock.unlock() }
            storage[account] = nil
            return errSecSuccess
        }
    }

    extension TransmissionTrustStore {
        /// Упрощённое in-memory хранилище отпечатков для тестов.
        static func inMemory() -> TransmissionTrustStore {
            let database = TransmissionTrustInMemoryDatabase()
            let interface = TransmissionTrustKeychainInterface(
                add: { query, _ in
                    let dict = query as NSDictionary
                    let account = dict[kSecAttrAccount as String] as? String ?? ""
                    let value = dict[kSecValueData as String] as? Data ?? Data()
                    let generic = dict[kSecAttrGeneric as String] as? Data ?? Data()
                    return database.add(account: account, value: value, generic: generic)
                },
                copyMatching: { query, result in
                    let dict = query as NSDictionary
                    let account = dict[kSecAttrAccount as String] as? String ?? ""
                    guard let entry = database.copy(account: account) else {
                        return errSecItemNotFound
                    }
                    if let result {
                        let response: [String: Any] = [
                            kSecValueData as String: entry.value,
                            kSecAttrGeneric as String: entry.generic
                        ]
                        result.pointee = response as CFDictionary
                    }
                    return errSecSuccess
                },
                update: { query, attributes in
                    let dict = query as NSDictionary
                    let account = dict[kSecAttrAccount as String] as? String ?? ""
                    let attributesDict = attributes as NSDictionary
                    let value = attributesDict[kSecValueData as String] as? Data ?? Data()
                    let generic = attributesDict[kSecAttrGeneric as String] as? Data ?? Data()
                    return database.update(account: account, value: value, generic: generic)
                },
                delete: { query in
                    let dict = query as NSDictionary
                    let account = dict[kSecAttrAccount as String] as? String ?? ""
                    return database.delete(account: account)
                }
            )
            return TransmissionTrustStore(interface: interface)
        }
    }
#endif
