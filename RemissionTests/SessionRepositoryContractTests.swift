import Foundation
import Testing

@testable import Remission

@Suite("SessionRepository Contract")
struct SessionRepositoryContractTests {
    @Test("placeholder возвращает предзаполненные значения без ошибок")
    func placeholderReturnsPreviewState() async throws {
        // Этот тест фиксирует поведение placeholder: он используется в превью
        // и обязан возвращать корректные значения без падений.
        let repository = SessionRepository.placeholder

        let handshake = try await repository.performHandshake()
        #expect(handshake.isCompatible == false)
        #expect(handshake.rpcVersion == 0)

        let state = try await repository.fetchState()
        #expect(state == .previewActive)

        let updated = try await repository.updateState(.init())
        #expect(updated == .previewActive)

        let compatibility = try await repository.checkCompatibility()
        #expect(compatibility.isCompatible == true)
        #expect(compatibility.rpcVersion == 0)
    }

    @Test("unimplemented бросает ошибку конфигурации для всех методов")
    func unimplementedThrowsForAllOperations() async {
        // Контракт unimplemented: любые вызовы должны сигнализировать о
        // неправильной конфигурации окружения.
        let repository = SessionRepository.unimplemented

        await expectNotConfigured("performHandshake") {
            _ = try await repository.performHandshake()
        }

        await expectNotConfigured("fetchState") {
            _ = try await repository.fetchState()
        }

        await expectNotConfigured("updateState") {
            _ = try await repository.updateState(.init())
        }

        await expectNotConfigured("checkCompatibility") {
            _ = try await repository.checkCompatibility()
        }
    }

    private func expectNotConfigured(
        _ method: String,
        operation: @Sendable () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Ожидали ошибку конфигурации для \(method), но вызов прошёл")
        } catch {
            #expect(
                error.localizedDescription
                    == "SessionRepository.\(method) is not configured for this environment."
            )
        }
    }
}
