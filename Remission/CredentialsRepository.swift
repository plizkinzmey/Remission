import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Репозиторий управления учетными данными Transmission поверх Keychain.
struct CredentialsRepository: Sendable {
    var save: @Sendable (TransmissionServerCredentials) async throws -> Void
    var load:
        @Sendable (TransmissionServerCredentialsKey) async throws -> TransmissionServerCredentials?
    var delete: @Sendable (TransmissionServerCredentialsKey) async throws -> Void

    func save(credentials: TransmissionServerCredentials) async throws {
        try await save(credentials)
    }

    func load(
        key: TransmissionServerCredentialsKey
    ) async throws -> TransmissionServerCredentials? {
        try await load(key)
    }

    func delete(key: TransmissionServerCredentialsKey) async throws {
        try await delete(key)
    }
}

#if canImport(ComposableArchitecture)
    extension CredentialsRepository: DependencyKey {
        static let liveValue: CredentialsRepository = {
            @Dependency(\.keychainCredentials) var keychain: KeychainCredentialsDependency
            @Dependency(\.credentialsAuditLogger) var auditLogger: CredentialsAuditLogger
            return CredentialsRepository.live(keychain: keychain, auditLogger: auditLogger)
        }()

        static let previewValue: CredentialsRepository = .unimplemented
        static let testValue: CredentialsRepository = .unimplemented
    }

    extension DependencyValues {
        var credentialsRepository: CredentialsRepository {
            get { self[CredentialsRepository.self] }
            set { self[CredentialsRepository.self] = newValue }
        }
    }

    extension CredentialsRepository {
        static func live(
            keychain: KeychainCredentialsDependency,
            auditLogger: CredentialsAuditLogger
        ) -> CredentialsRepository {
            CredentialsRepository(
                save: { credentials in
                    let descriptor: CredentialsServerDescriptor =
                        CredentialsServerDescriptor(key: credentials.key)
                    do {
                        try keychain.save(credentials)
                        auditLogger(.saveSucceeded(descriptor))
                    } catch {
                        auditLogger(.saveFailed(descriptor, describe(error)))
                        throw error
                    }
                },
                load: { key in
                    let descriptor: CredentialsServerDescriptor =
                        CredentialsServerDescriptor(key: key)
                    do {
                        if let credentials = try keychain.load(key) {
                            auditLogger(.loadSucceeded(descriptor))
                            return credentials
                        } else {
                            auditLogger(.loadMissing(descriptor))
                            return nil
                        }
                    } catch {
                        auditLogger(.loadFailed(descriptor, describe(error)))
                        throw error
                    }
                },
                delete: { key in
                    let descriptor: CredentialsServerDescriptor =
                        CredentialsServerDescriptor(key: key)
                    do {
                        try keychain.delete(key)
                        auditLogger(.deleteSucceeded(descriptor))
                    } catch {
                        auditLogger(.deleteFailed(descriptor, describe(error)))
                        throw error
                    }
                }
            )
        }

        fileprivate static var unimplemented: CredentialsRepository {
            CredentialsRepository(
                save: { _ in throw CredentialsRepositoryError.notConfigured("save") },
                load: { _ in throw CredentialsRepositoryError.notConfigured("load") },
                delete: { _ in throw CredentialsRepositoryError.notConfigured("delete") }
            )
        }

        fileprivate static func describe(_ error: Error) -> String {
            let localized: String = (error as NSError).localizedDescription
            return localized.isEmpty ? String(describing: error) : localized
        }
    }

    private enum CredentialsRepositoryError: Error, LocalizedError, Sendable {
        case notConfigured(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let name):
                return "CredentialsRepository.\(name) is not configured for this environment."
            }
        }
    }
#endif
