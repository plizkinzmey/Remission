#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    @DependencyClient
    struct KeychainCredentialsDependency: Sendable {
        var save: @Sendable (TransmissionServerCredentials) throws -> Void
        var load:
            @Sendable (TransmissionServerCredentialsKey) throws -> TransmissionServerCredentials?
        var delete: @Sendable (TransmissionServerCredentialsKey) throws -> Void
    }

    extension KeychainCredentialsDependency {
        fileprivate static let placeholder: Self = Self(
            save: { _ in throw KeychainCredentialsDependencyError.notConfigured("save") },
            load: { _ in throw KeychainCredentialsDependencyError.notConfigured("load") },
            delete: { _ in throw KeychainCredentialsDependencyError.notConfigured("delete") }
        )
    }

    enum KeychainCredentialsDependencyError: Error, LocalizedError, Sendable {
        case notConfigured(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let name):
                return
                    "KeychainCredentialsDependency.\(name) is not configured for this environment."
            }
        }
    }

    extension KeychainCredentialsDependency: TestDependencyKey {
        static let testValue: Self = placeholder
        static let previewValue: Self = placeholder
    }

    extension DependencyValues {
        @preconcurrency var keychainCredentials: KeychainCredentialsDependency {
            get { self[KeychainCredentialsDependency.self] }
            set { self[KeychainCredentialsDependency.self] = newValue }
        }
    }
#endif
