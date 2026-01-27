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

    @Test("fileBased persists changes to disk")
    func fileBasedCRUDFlow() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString
        ).appendingPathExtension("json")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let repository = ServerConfigRepository.fileBased(fileURL: tempURL)

        // Initial load (empty)
        let initial = try await repository.load()
        #expect(initial.isEmpty)

        // Upsert
        let server = ServerConfig.previewLocalHTTP
        let afterUpsert = try await repository.upsert(server)
        #expect(afterUpsert.count == 1)

        // Verify persistence by creating a new repo pointing to the same file
        let repo2 = ServerConfigRepository.fileBased(fileURL: tempURL)
        let reloaded = try await repo2.load()
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == server.id)

        // Delete via first repository
        let afterDelete = try await repository.delete([server.id])
        #expect(afterDelete.isEmpty)

        // Verify persistence of deletion by creating a NEW repo (repo3)
        // repo2 has stale cache, which is expected behavior for this simple implementation
        let repo3 = ServerConfigRepository.fileBased(fileURL: tempURL)
        let reloadedAfterDelete = try await repo3.load()
        #expect(reloadedAfterDelete.isEmpty)
    }
}
