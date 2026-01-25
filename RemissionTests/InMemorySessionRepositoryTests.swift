import Foundation
import Testing

@testable import Remission

@Suite("InMemorySessionRepository")
struct InMemorySessionRepositoryTests {
    @Test("updateState применяет изменения лимитов, очередей и seed ratio")
    func updateStateAppliesSessionUpdate() async throws {
        // Проверяем, что in-memory репозиторий корректно маппит SessionUpdate в SessionState.
        let store = InMemorySessionRepositoryStore(
            handshake: .init(
                sessionID: "sid", rpcVersion: 17, minimumSupportedRpcVersion: 14,
                serverVersionDescription: "4.0.3", isCompatible: true),
            state: .previewActive,
            compatibility: .init(isCompatible: true, rpcVersion: 17)
        )
        let repository = SessionRepository.inMemory(store: store)

        let update = SessionRepository.SessionUpdate(
            speedLimits: .init(
                download: .init(isEnabled: true, kilobytesPerSecond: 512),
                upload: .init(isEnabled: false, kilobytesPerSecond: 128),
                alternative: .init(
                    isEnabled: true, downloadKilobytesPerSecond: 256, uploadKilobytesPerSecond: 64)
            ),
            queue: .init(
                downloadLimit: .init(isEnabled: true, count: 3),
                seedLimit: .init(isEnabled: false, count: 5),
                considerStalled: true,
                stalledMinutes: 30
            ),
            seedRatioLimit: .init(isEnabled: true, value: 1.5)
        )

        let newState = try await repository.updateState(update)

        #expect(newState.speedLimits.download.kilobytesPerSecond == 512)
        #expect(newState.speedLimits.alternative.isEnabled)
        #expect(newState.queue.downloadLimit.count == 3)
        #expect(newState.queue.considerStalled)
        #expect(newState.seedRatioLimit.value == 1.5)

        let storedState = try await repository.fetchState()
        #expect(storedState == newState)
    }

    @Test("операция updateState падает, когда помечена как failing")
    func updateStateFailureIsPropagated() async {
        // Error-path обязателен: он используется для проверки UI-обработки ошибок.
        let store = InMemorySessionRepositoryStore(
            handshake: .init(
                sessionID: nil, rpcVersion: 17, minimumSupportedRpcVersion: 14,
                serverVersionDescription: nil, isCompatible: true),
            state: .previewActive,
            compatibility: .init(isCompatible: true, rpcVersion: 17)
        )
        let repository = SessionRepository.inMemory(store: store)

        await store.markFailure(.updateState)

        do {
            _ = try await repository.updateState(
                .init(seedRatioLimit: .init(isEnabled: true, value: 2.0))
            )
            Issue.record("Ожидали ошибку updateState, но она не была брошена")
        } catch let error as InMemorySessionRepositoryError {
            guard case .operationFailed(.updateState) = error else {
                Issue.record("Получили неожиданный InMemorySessionRepositoryError: \(error)")
                return
            }
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}
