import ComposableArchitecture
import Dependencies
import Foundation

extension TransmissionServerCredentialsKey {
    static var preview: TransmissionServerCredentialsKey {
        TransmissionServerCredentialsKey(
            host: "preview.remote",
            port: 9091,
            isSecure: false,
            username: "remission-preview"
        )
    }
}

extension TransmissionServerCredentials {
    static var preview: TransmissionServerCredentials {
        TransmissionServerCredentials(
            key: .preview,
            password: "preview-password"
        )
    }
}

extension CredentialsRepository {
    /// In-memory реализация для UI-тестов, исключающая обращения к Keychain.
    static func uiTestInMemory(
        initialCredentials: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]
    ) -> CredentialsRepository {
        let store = UITestCredentialsStore(initial: initialCredentials)
        return CredentialsRepository(
            save: { credentials in
                await store.save(credentials)
            },
            load: { key in
                await store.load(key)
            },
            delete: { key in
                await store.delete(key)
            }
        )
    }

    static func previewMock(
        load:
            @Sendable @escaping (TransmissionServerCredentialsKey) async throws ->
            TransmissionServerCredentials? = { _ in .preview },
        save: @Sendable @escaping (TransmissionServerCredentials) async throws -> Void = { _ in },
        delete: @Sendable @escaping (TransmissionServerCredentialsKey) async throws -> Void = { _ in
        }
    ) -> CredentialsRepository {
        CredentialsRepository(save: save, load: load, delete: delete)
    }
}

private actor UITestCredentialsStore {
    private var storage: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]

    init(initial: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]) {
        storage = initial
    }

    func save(_ credentials: TransmissionServerCredentials) {
        storage[credentials.key] = credentials
    }

    func load(_ key: TransmissionServerCredentialsKey) -> TransmissionServerCredentials? {
        storage[key]
    }

    func delete(_ key: TransmissionServerCredentialsKey) {
        storage[key] = nil
    }
}

extension TransmissionClientDependency {
    static func previewMock(
        sessionGet: @Sendable @escaping () async throws -> TransmissionResponse = {
            TransmissionResponse(result: "success")
        }
    ) -> TransmissionClientDependency {
        var dependency = TransmissionClientDependency.placeholder
        dependency.sessionGet = sessionGet
        return dependency
    }
}
