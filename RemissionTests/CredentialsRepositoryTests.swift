import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("CredentialsRepository")
struct CredentialsRepositoryTests {
    @Test("Save delegates to Keychain and logs success")
    func saveSuccess() async throws {
        let key: TransmissionServerCredentialsKey = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "admin"
        )
        let credentials: TransmissionServerCredentials = TransmissionServerCredentials(
            key: key, password: "super-secret")

        let savedCredentials: LockedBox<TransmissionServerCredentials?> = LockedBox(nil)
        let events: LockedBox<[CredentialsAuditEvent]> = LockedBox([])

        let keychain: KeychainCredentialsDependency = KeychainCredentialsDependency(
            save: { creds in savedCredentials.set(creds) },
            load: { _ in nil },
            delete: { _ in }
        )
        let auditLogger: CredentialsAuditLogger = CredentialsAuditLogger { event in
            events.append(event)
        }
        let repository: CredentialsRepository = CredentialsRepository.live(
            keychain: keychain,
            auditLogger: auditLogger
        )

        try await withDependencies {
            $0.credentialsRepository = repository
        } operation: {
            @Dependency(\.credentialsRepository) var repository: CredentialsRepository
            try await repository.save(credentials: credentials)
        }

        #expect(savedCredentials.value == credentials)
        #expect(events.value.contains(.saveSucceeded(CredentialsServerDescriptor(key: key))))
        #expect(
            events.value.allSatisfy { event in
                event.message().contains("admin") == false
            })
    }

    @Test("Save failure propagates error and logs failure")
    func saveFailurePropagatesError() async {
        enum DummyError: Error, Equatable { case failed }

        let key: TransmissionServerCredentialsKey = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "operator"
        )
        let credentials: TransmissionServerCredentials = TransmissionServerCredentials(
            key: key,
            password: "value"
        )
        let events: LockedBox<[CredentialsAuditEvent]> = LockedBox([])

        let keychain: KeychainCredentialsDependency = KeychainCredentialsDependency(
            save: { _ in throw DummyError.failed },
            load: { _ in nil },
            delete: { _ in }
        )
        let auditLogger: CredentialsAuditLogger = CredentialsAuditLogger { event in
            events.append(event)
        }
        let repository: CredentialsRepository = CredentialsRepository.live(
            keychain: keychain,
            auditLogger: auditLogger
        )

        let operationError: Error? = await withDependencies {
            $0.credentialsRepository = repository
        } operation: {
            @Dependency(\.credentialsRepository) var repository: CredentialsRepository
            do {
                try await repository.save(credentials: credentials)
                return nil as Error?
            } catch {
                return error
            }
        }

        #expect(operationError as? DummyError == DummyError.failed)
        #expect(
            events.value.contains { event in
                if case .saveFailed(let descriptor, _) = event {
                    return descriptor == CredentialsServerDescriptor(key: key)
                }
                return false
            })
    }

    @Test("Load missing credentials logs appropriate event")
    func loadMissing() async throws {
        let key: TransmissionServerCredentialsKey = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "admin"
        )
        let events: LockedBox<[CredentialsAuditEvent]> = LockedBox([])

        let keychain: KeychainCredentialsDependency = KeychainCredentialsDependency(
            save: { _ in },
            load: { _ in nil },
            delete: { _ in }
        )
        let auditLogger: CredentialsAuditLogger = CredentialsAuditLogger { event in
            events.append(event)
        }
        let repository: CredentialsRepository = CredentialsRepository.live(
            keychain: keychain,
            auditLogger: auditLogger
        )

        let loaded: TransmissionServerCredentials? = try await withDependencies {
            $0.credentialsRepository = repository
        } operation: {
            @Dependency(\.credentialsRepository) var repository: CredentialsRepository
            return try await repository.load(key: key)
        }

        #expect(loaded == nil)
        #expect(events.value.contains(.loadMissing(CredentialsServerDescriptor(key: key))))
    }

    @Test("Delete propagates errors")
    func deleteFailure() async {
        enum DummyError: Error, Equatable { case failed }

        let key: TransmissionServerCredentialsKey = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "admin"
        )

        let events: LockedBox<[CredentialsAuditEvent]> = LockedBox([])

        let keychain: KeychainCredentialsDependency = KeychainCredentialsDependency(
            save: { _ in },
            load: { _ in nil },
            delete: { _ in throw DummyError.failed }
        )
        let auditLogger: CredentialsAuditLogger = CredentialsAuditLogger { event in
            events.append(event)
        }
        let repository: CredentialsRepository = CredentialsRepository.live(
            keychain: keychain,
            auditLogger: auditLogger
        )

        let operationError: Error? = await withDependencies {
            $0.credentialsRepository = repository
        } operation: {
            @Dependency(\.credentialsRepository) var repository: CredentialsRepository
            do {
                try await repository.delete(key: key)
                return nil as Error?
            } catch {
                return error
            }
        }

        #expect(operationError as? DummyError == DummyError.failed)
        #expect(
            events.value.contains { event in
                if case .deleteFailed(let descriptor, _) = event {
                    return descriptor == CredentialsServerDescriptor(key: key)
                }
                return false
            })
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private var valueStorage: Value
    private let lock: NSLock = NSLock()

    init(_ value: Value) {
        self.valueStorage = value
    }

    func append(_ element: Value.Element) where Value: RangeReplaceableCollection {
        lock.lock()
        valueStorage.append(element)
        lock.unlock()
    }

    func set(_ newValue: Value) {
        lock.lock()
        valueStorage = newValue
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return valueStorage
    }
}
