import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("AppDependencies")
struct AppDependenciesTests {
    @Test("appPreview использует noop logger и preview credentials")
    func appPreviewUsesNoopLoggerAndPreviewCredentials() async throws {
        // Проверяем, что preview окружение не пишет реальные логи
        // и использует предсказуемые креды.
        let dependencies = AppDependencies.makePreview()
        #expect(dependencies.appLogger.isNoop)

        let credentials = try await dependencies.credentialsRepository.load(key: .preview)
        #expect(credentials?.password == "preview-password")
    }

    @Test("appTest использует noop logger и inMemory diagnostics log")
    func appTestUsesNoopLogger() async throws {
        // Тестовое окружение должно быть максимально безопасным и детерминированным.
        let dependencies = AppDependencies.makeTestDefaults()
        #expect(dependencies.appLogger.isNoop)

        let entries = try await dependencies.diagnosticsLogStore.load(.init())
        #expect(entries.isEmpty)
    }

    @Test("makeLive оставляет transmissionClient placeholder")
    func makeLiveLeavesTransmissionClientPlaceholder() async {
        // В live-окружении мы оставляем placeholder и настраиваем его позже.
        let dependencies = AppDependencies.makeLive()

        do {
            _ = try await dependencies.transmissionClient.sessionGet()
            Issue.record("Ожидали placeholder ошибку, но sessionGet прошёл")
        } catch {
            #expect(
                error.localizedDescription
                    == "TransmissionClientDependency.sessionGet is not configured for this environment."
            )
        }
    }

    @Test("makeUITest для serverListSample подставляет серверы")
    func makeUITestServerListScenarioSeedsServers() async throws {
        // Сценарий serverListSample должен заполнить repository серверами из фикстуры.
        let dependencies = AppDependencies.makeUITest(
            fixture: .serverListSample,
            scenario: nil,
            environment: [:]
        )

        let servers = try await dependencies.serverConfigRepository.load()
        #expect(servers.count == 2)
        #expect(servers[0].name == "UI Test NAS")
    }

    @Test("makeUITest torrentListOffline возвращает ошибку на fetchList")
    func makeUITestTorrentListOfflineThrowsOnFetchList() async {
        // В offline-сценарии репозиторий торрентов должен возвращать сетевую ошибку.
        let dependencies = AppDependencies.makeUITest(
            fixture: nil,
            scenario: .torrentListOffline,
            environment: [:]
        )

        do {
            _ = try await dependencies.torrentRepository.fetchList()
            Issue.record("Ожидали APIError.networkUnavailable, но fetchList прошёл")
        } catch let error as APIError {
            #expect(error == .networkUnavailable)
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}
