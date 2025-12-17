import Foundation
import Security

/// Ошибки Keychain-обертки.
enum KeychainCredentialsStoreError: Error, Equatable, Sendable {
    case unexpectedPasswordEncoding
    case unexpectedItemData
    case notFound
    case osStatus(OSStatus)
}

extension KeychainCredentialsStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unexpectedPasswordEncoding:
            return "Не удалось закодировать пароль для сохранения в Keychain."
        case .unexpectedItemData:
            return "Запись Keychain содержит неожиданные данные."
        case .notFound:
            return "Запись в Keychain не найдена."
        case .osStatus(let status):
            return Self.describe(status)
        }
    }

    private static func describe(_ status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "OSStatus \(status)"
    }
}

/// Абстракция функций Keychain Services для тестируемости.
struct KeychainItemInterface: Sendable {
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

/// Метаданные, сохраняемые вместе с паролем в поле `kSecAttrGeneric`.
private struct TransmissionCredentialsMetadata: Codable, Equatable {
    var host: String
    var port: Int
    var isSecure: Bool
    var username: String
}

/// Обертка над Keychain для хранения учетных данных Transmission.
struct KeychainCredentialsStore: Sendable {
    private enum Constants {
        static let serviceIdentifier: String = "com.remission.transmission"
    }

    private let interface: KeychainItemInterface

    init(interface: KeychainItemInterface = .live) {
        self.interface = interface
    }

    /// Сохранение или обновление учетных данных.
    func save(_ credentials: TransmissionServerCredentials) throws {
        let passwordData: Data = try Data(password: credentials.password)
        let metadata: TransmissionCredentialsMetadata = TransmissionCredentialsMetadata(
            host: credentials.key.host,
            port: credentials.key.port,
            isSecure: credentials.key.isSecure,
            username: credentials.key.username
        )
        let metadataData: Data = try JSONEncoder().encode(metadata)

        var addQuery: [String: Any] = baseQuery(for: credentials.key)
        addQuery[kSecValueData as String] = passwordData
        addQuery[kSecAttrGeneric as String] = metadataData

        let status: OSStatus = interface.add(addQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try update(credentials, passwordData: passwordData, metadataData: metadataData)
        default:
            throw mapStatus(status)
        }
    }

    /// Получение учетных данных (nil, если запись отсутствует).
    func load(key: TransmissionServerCredentialsKey) throws -> TransmissionServerCredentials? {
        var query: [String: Any] = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status: OSStatus = interface.copyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard
                let item = result as? [String: Any],
                let passwordData = item[kSecValueData as String] as? Data,
                let password = String(data: passwordData, encoding: .utf8)
            else {
                throw KeychainCredentialsStoreError.unexpectedItemData
            }

            let metadata: TransmissionCredentialsMetadata? = {
                guard let data: Data = item[kSecAttrGeneric as String] as? Data else {
                    return nil
                }
                return try? JSONDecoder().decode(
                    TransmissionCredentialsMetadata.self,
                    from: data
                )
            }()

            let resolvedKey: TransmissionServerCredentialsKey =
                metadata.map {
                    TransmissionServerCredentialsKey(
                        host: $0.host,
                        port: $0.port,
                        isSecure: $0.isSecure,
                        username: $0.username
                    )
                } ?? key

            return TransmissionServerCredentials(
                key: resolvedKey,
                password: password
            )

        case errSecItemNotFound:
            return nil
        default:
            throw mapStatus(status)
        }
    }

    /// Удаление учетных данных. Отсутствие записи не считается ошибкой.
    func delete(key: TransmissionServerCredentialsKey) throws {
        let query: [String: Any] = baseQuery(for: key)
        let status: OSStatus = interface.delete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw mapStatus(status)
        }
    }

    // MARK: - Helpers

    private func update(
        _ credentials: TransmissionServerCredentials,
        passwordData: Data,
        metadataData: Data
    ) throws {
        let query: [String: Any] = baseQuery(for: credentials.key)
        let attributes: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrGeneric as String: metadataData
        ]

        let status: OSStatus = interface.update(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw mapStatus(status)
        }
    }

    private func baseQuery(for key: TransmissionServerCredentialsKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.serviceIdentifier,
            kSecAttrAccount as String: key.accountIdentifier,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: kCFBooleanFalse as CFBoolean
        ]
        #if !os(macOS)
            // Data protection keychain доступен на iOS/watchOS/tvOS/visionOS; на macOS без entitlements может вернуть errSecMissingEntitlement.
            query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    private func mapStatus(_ status: OSStatus) -> KeychainCredentialsStoreError {
        switch status {
        case errSecItemNotFound:
            return .notFound
        default:
            return .osStatus(status)
        }
    }
}

extension Data {
    fileprivate init(password: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainCredentialsStoreError.unexpectedPasswordEncoding
        }
        self = data
    }
}
