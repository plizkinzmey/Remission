#if canImport(ComposableArchitecture)
    import Dependencies
    import Foundation

    extension KeychainCredentialsDependency: DependencyKey {
        static var liveValue: Self {
            .live(
                serviceIdentifier: AppStorageNamespace.live().credentialsKeychainServiceIdentifier)
        }
    }

    extension KeychainCredentialsDependency {
        static func live(
            serviceIdentifier: String = KeychainCredentialsStore.defaultServiceIdentifier
        ) -> Self {
            let store = KeychainCredentialsStore(serviceIdentifier: serviceIdentifier)
            return Self(
                save: { credentials in
                    try store.save(credentials)
                },
                load: { key in
                    try store.load(key: key)
                },
                delete: { key in
                    try store.delete(key: key)
                }
            )
        }
    }
#endif
