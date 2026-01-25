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
}
