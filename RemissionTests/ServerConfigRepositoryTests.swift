import Foundation
import Testing

@testable import Remission

@Suite("ServerConfigRepository")
struct ServerConfigRepositoryTests {
    @Test("inMemory load возвращает initial, upsert обновляет по id, delete удаляет")
    func inMemoryCRUDFlow() async throws {
        // Этот тест покрывает полный жизненный цикл конфигурации сервера в inMemory-репозитории.
        let initial = [ServerConfig.previewLocalHTTP, ServerConfig.previewSecureSeedbox]
        let repository = ServerConfigRepository.inMemory(initial: initial)

        let loaded = try await repository.load()
        #expect(loaded.count == 2)

        var updatedServer = ServerConfig.previewLocalHTTP
        updatedServer.name = "Updated Local"

        let afterUpsert = try await repository.upsert(updatedServer)
        #expect(afterUpsert.count == 2)
        #expect(afterUpsert.first(where: { $0.id == updatedServer.id })?.name == "Updated Local")

        let afterDelete = try await repository.delete([updatedServer.id])
        #expect(afterDelete.count == 1)
        #expect(afterDelete.contains(where: { $0.id == updatedServer.id }) == false)
    }
}
