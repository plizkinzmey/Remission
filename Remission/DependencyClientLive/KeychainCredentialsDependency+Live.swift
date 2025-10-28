#if canImport(ComposableArchitecture)
    import Dependencies
    import Foundation

    extension KeychainCredentialsDependency: DependencyKey {
        static let liveValue: Self = {
            let store: KeychainCredentialsStore = KeychainCredentialsStore()
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
        }()
    }
#endif
