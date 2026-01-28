import Foundation
import Testing

@testable import Remission

@Suite("CredentialsRepository")
struct CredentialsRepositoryTests {
    @Test("live(save:) логирует saveSucceeded при успешном сохранении")
    func saveSuccessEmitsAuditEvent() async throws {
        // Этот тест защищает аудит-логирование: успех должен быть отражён в событиях.
        let recorder = CredentialsAuditRecorder()
        let keychain = makeKeychainDependency(saveResult: .success(()))
        let auditLogger = CredentialsAuditLogger(appLogger: .noop, eventSink: recorder.record)
        let repository = CredentialsRepository.live(keychain: keychain, auditLogger: auditLogger)

        let key = TransmissionServerCredentialsKey(
            host: "nas.local", port: 9091, isSecure: false, username: "alice")
        let credentials = TransmissionServerCredentials(key: key, password: "secret")

        try await repository.save(credentials: credentials)

        let events = recorder.snapshot()
        #expect(events.contains(.saveSucceeded(.init(key: key))))
    }

    @Test("live(load:) логирует loadMissing, когда credentials отсутствуют")
    func loadMissingEmitsAuditEvent() async throws {
        // Это важный UX-сценарий: отличаем «нет записи» от «сломалась Keychain».
        let recorder = CredentialsAuditRecorder()
        let keychain = makeKeychainDependency(loadResult: .success(nil))
        let auditLogger = CredentialsAuditLogger(appLogger: .noop, eventSink: recorder.record)
        let repository = CredentialsRepository.live(keychain: keychain, auditLogger: auditLogger)

        let key = TransmissionServerCredentialsKey(
            host: "nas.local", port: 9091, isSecure: false, username: "alice")
        let loaded = try await repository.load(key: key)

        #expect(loaded == nil)
        #expect(recorder.snapshot().contains(.loadMissing(.init(key: key))))
    }

    @Test("live(load:) пробрасывает ошибку и логирует loadFailed")
    func loadFailureRethrowsAndEmitsAuditEvent() async {
        // При ошибках важно и не потерять ошибку, и зафиксировать её в аудите.
        enum ExpectedError: Error { case boom }

        let recorder = CredentialsAuditRecorder()
        let keychain = makeKeychainDependency(loadResult: .failure(ExpectedError.boom))
        let auditLogger = CredentialsAuditLogger(appLogger: .noop, eventSink: recorder.record)
        let repository = CredentialsRepository.live(keychain: keychain, auditLogger: auditLogger)

        let key = TransmissionServerCredentialsKey(
            host: "nas.local", port: 9091, isSecure: false, username: "alice")

        do {
            _ = try await repository.load(key: key)
            Issue.record("Ожидали ошибку load, но она не была брошена")
        } catch {
            let events = recorder.snapshot()
            #expect(
                events.contains { event in
                    if case .loadFailed(let descriptor, _) = event {
                        return descriptor == .init(key: key)
                    }
                    return false
                })
        }
    }
}

private final class CredentialsAuditRecorder: @unchecked Sendable {
    private var events: [CredentialsAuditEvent] = []
    private let lock = NSLock()

    func record(_ event: CredentialsAuditEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [CredentialsAuditEvent] {
        lock.lock()
        let snapshot = events
        lock.unlock()
        return snapshot
    }
}

private func makeKeychainDependency(
    saveResult: Result<Void, Error> = .success(()),
    loadResult: Result<TransmissionServerCredentials?, Error> = .success(nil),
    deleteResult: Result<Void, Error> = .success(())
) -> KeychainCredentialsDependency {
    KeychainCredentialsDependency(
        save: { _ in
            switch saveResult {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        },
        load: { _ in
            switch loadResult {
            case .success(let credentials):
                return credentials
            case .failure(let error):
                throw error
            }
        },
        delete: { _ in
            switch deleteResult {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        }
    )
}
