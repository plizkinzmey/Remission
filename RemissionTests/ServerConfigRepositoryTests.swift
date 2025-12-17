import Foundation
import Testing

@testable import Remission

struct ServerConfigRepositoryTests {
    @Test("In-memory store supports load, upsert и delete")
    func inMemoryStoreHandlesCrud() async throws {
        var initialServer = ServerConfig.previewLocalHTTP
        initialServer.id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

        var newServer = ServerConfig.previewSecureSeedbox
        newServer.id = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!

        let repository = ServerConfigRepository.inMemory(initial: [initialServer])

        let loaded = try await repository.load()
        #expect(loaded == [initialServer])

        let afterUpsert = try await repository.upsert(newServer)
        #expect(afterUpsert.contains(where: { $0.id == newServer.id }))

        let afterDelete = try await repository.delete([initialServer.id])
        #expect(afterDelete.count == 1)
        #expect(afterDelete.first?.id == newServer.id)
    }

    @Test("File store persists records to disk")
    func fileStorePersistsRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("server-config-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("servers.json", isDirectory: false)
        var server = ServerConfig.previewSecureSeedbox
        server.id = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!

        let repository = ServerConfigRepository.fileBased(fileURL: fileURL)

        let afterUpsert = try await repository.upsert(server)
        #expect(afterUpsert.count == 1)
        #expect(afterUpsert.first?.id == server.id)

        let persistedSnapshot = ServerConfigStoragePaths.loadSnapshot(fileURL: fileURL)
        #expect(persistedSnapshot.count == 1)
        #expect(persistedSnapshot.first?.id == server.id)

        let afterDelete = try await repository.delete([server.id])
        #expect(afterDelete.isEmpty)
        #expect(ServerConfigStoragePaths.loadSnapshot(fileURL: fileURL).isEmpty)
    }

    @Test("File store propagates write failures")
    func fileStorePropagatesWriteFailure() async {
        let fileURL = URL(fileURLWithPath: "/dev/null/servers.json")
        let repository = ServerConfigRepository.fileBased(fileURL: fileURL)

        do {
            _ = try await repository.upsert(.previewLocalHTTP)
            Issue.record("Ожидалось исключение при попытке записи в недоступный путь")
        } catch let error as ServerConfigRepositoryError {
            guard case .failedToPersist = error else {
                Issue.record("Ожидалась ошибка failedToPersist, получено: \(error)")
                return
            }
        } catch {
            Issue.record("Неожиданная ошибка при upsert: \(error)")
        }
    }
}
