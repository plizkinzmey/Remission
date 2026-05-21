import Dependencies
import Foundation
import XCTest

@testable import Remission

final class KeychainCredentialsDependencyTests: XCTestCase {
    private let key = TransmissionServerCredentialsKey(
        host: "example.com",
        port: 9091,
        isSecure: true,
        username: "user"
    )

    // Проверяет, что стандартная test-зависимость явно сообщает о
    // неконфигурированном Keychain-клиенте при сохранении.
    func testDefaultDependencySaveThrowsNotConfigured() throws {
        let dependencies = DependencyValues()
        let credentials = TransmissionServerCredentials(key: key, password: "secret")

        XCTAssertThrowsError(try dependencies.keychainCredentials.save(credentials)) { error in
            XCTAssertTrue(error is KeychainCredentialsDependencyError)
        }
    }

    // Проверяет, что стандартная test-зависимость падает и при чтении.
    func testDefaultDependencyLoadThrowsNotConfigured() throws {
        let dependencies = DependencyValues()

        XCTAssertThrowsError(try dependencies.keychainCredentials.load(key)) { error in
            XCTAssertTrue(error is KeychainCredentialsDependencyError)
        }
    }

    // Проверяет, что стандартная test-зависимость падает и при удалении.
    func testDefaultDependencyDeleteThrowsNotConfigured() throws {
        let dependencies = DependencyValues()

        XCTAssertThrowsError(try dependencies.keychainCredentials.delete(key)) { error in
            XCTAssertTrue(error is KeychainCredentialsDependencyError)
        }
    }

    // Проверяет, что liveValue сохраняет, читает и удаляет ключ в Keychain.
    func testLiveDependencySaveLoadDeleteRoundTrip() async throws {
        let uniqueKey = TransmissionServerCredentialsKey(
            host: "example.com",
            port: 9091,
            isSecure: true,
            username: "user-\(UUID().uuidString)"
        )
        let credentials = TransmissionServerCredentials(key: uniqueKey, password: "secret")

        let result = try await Task.detached {
            let live = KeychainCredentialsDependency.liveValue

            // Ensure clean slate in case of a previous run.
            try? live.delete(uniqueKey)

            try live.save(credentials)
            let loaded = try live.load(uniqueKey)

            try live.delete(uniqueKey)
            let deleted = try live.load(uniqueKey)

            return (loaded, deleted)
        }.value

        XCTAssertEqual(result.0, credentials)
        XCTAssertNil(result.1)
    }
}
