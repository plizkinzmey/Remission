import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("KeychainCredentialsDependency Tests")
struct KeychainCredentialsDependencyTests {
    private let key = TransmissionServerCredentialsKey(
        host: "example.com",
        port: 9091,
        isSecure: true,
        username: "user"
    )

    // Проверяет, что стандартная test-зависимость явно сообщает о
    // неконфигурированном Keychain-клиенте при сохранении.
    @Test
    func defaultDependencySaveThrowsNotConfigured() throws {
        let dependencies = DependencyValues()
        let credentials = TransmissionServerCredentials(key: key, password: "secret")

        #expect(throws: KeychainCredentialsDependencyError.self) {
            try dependencies.keychainCredentials.save(credentials)
        }
    }

    // Проверяет, что стандартная test-зависимость падает и при чтении.
    @Test
    func defaultDependencyLoadThrowsNotConfigured() throws {
        let dependencies = DependencyValues()

        #expect(throws: KeychainCredentialsDependencyError.self) {
            _ = try dependencies.keychainCredentials.load(key)
        }
    }

    // Проверяет, что стандартная test-зависимость падает и при удалении.
    @Test
    func defaultDependencyDeleteThrowsNotConfigured() throws {
        let dependencies = DependencyValues()

        #expect(throws: KeychainCredentialsDependencyError.self) {
            try dependencies.keychainCredentials.delete(key)
        }
    }

    // Проверяет, что liveValue сохраняет, читает и удаляет ключ в Keychain.
    @Test
    func liveDependencySaveLoadDeleteRoundTrip() throws {
        let uniqueKey = TransmissionServerCredentialsKey(
            host: "example.com",
            port: 9091,
            isSecure: true,
            username: "user-\(UUID().uuidString)"
        )
        let credentials = TransmissionServerCredentials(key: uniqueKey, password: "secret")
        let live = KeychainCredentialsDependency.liveValue

        // Ensure clean slate in case of a previous run.
        try? live.delete(uniqueKey)

        try live.save(credentials)
        let loaded = try live.load(uniqueKey)
        #expect(loaded == credentials)

        try live.delete(uniqueKey)
        let deleted = try live.load(uniqueKey)
        #expect(deleted == nil)
    }
}
