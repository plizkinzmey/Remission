import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Репозиторий сохранённых серверов Transmission.
/// Хранит публичные параметры подключения (без паролей) и позволяет их загружать/обновлять.
struct ServerConfigRepository: Sendable {
    var load: @Sendable () async throws -> [ServerConfig]
    var upsert: @Sendable (ServerConfig) async throws -> [ServerConfig]
    var delete: @Sendable ([UUID]) async throws -> [ServerConfig]
}

#if canImport(ComposableArchitecture)
    extension ServerConfigRepository: DependencyKey {
        static var liveValue: ServerConfigRepository { .fileBased() }
        static var previewValue: ServerConfigRepository {
            .inMemory(initial: [
                .previewLocalHTTP,
                .previewSecureSeedbox
            ])
        }
        static var testValue: ServerConfigRepository { .inMemory(initial: []) }
    }

    extension DependencyValues {
        var serverConfigRepository: ServerConfigRepository {
            get { self[ServerConfigRepository.self] }
            set { self[ServerConfigRepository.self] = newValue }
        }
    }
#endif

enum ServerConfigRepositoryError: Error, LocalizedError, Sendable {
    case failedToLoad(String)
    case failedToPersist(String)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .failedToLoad(let details):
            return "Не удалось загрузить сохранённые серверы: \(details)"
        case .failedToPersist(let details):
            return "Не удалось сохранить серверы: \(details)"
        case .invalidConfiguration(let details):
            return "Некорректная конфигурация сервера: \(details)"
        }
    }
}

extension ServerConfigRepository {
    /// Файловая реализация (Application Support/servers.json).
    static func fileBased(
        fileManager _: FileManager = .default,
        fileURL: URL = ServerConfigStoragePaths.defaultURL()
    ) -> ServerConfigRepository {
        let store = ServerConfigFileStore(
            fileURL: fileURL
        )
        let mapper = TransmissionDomainMapper()

        return ServerConfigRepository(
            load: {
                try await store.load()
                    .map { try mapper.mapServerConfig(record: $0, credentials: nil) }
            },
            upsert: { server in
                let record = makeRecord(from: server)
                let updated = try await store.upsert(record)
                return try updated.map { try mapper.mapServerConfig(record: $0, credentials: nil) }
            },
            delete: { ids in
                let updated = try await store.delete(ids: ids)
                return try updated.map { try mapper.mapServerConfig(record: $0, credentials: nil) }
            }
        )
    }

    /// Ин-мемори реализация для превью/тестов.
    static func inMemory(initial: [ServerConfig]) -> ServerConfigRepository {
        let store = InMemoryServerConfigStore(initial: initial)

        return ServerConfigRepository(
            load: {
                await store.snapshot()
            },
            upsert: { server in
                await store.upsert(server)
            },
            delete: { ids in
                await store.delete(ids: ids)
            }
        )
    }

    private static func makeRecord(from server: ServerConfig) -> StoredServerConfigRecord {
        let path =
            server.connection.path == "/transmission/rpc"
            ? nil
            : server.connection.path
        let security: StoredSecurity =
            switch server.security {
            case .http:
                .init(isSecure: false)
            case .https:
                .init(isSecure: true)
            }

        return StoredServerConfigRecord(
            id: server.id,
            name: server.name,
            host: server.connection.host,
            port: server.connection.port,
            path: path,
            isSecure: security.isSecure,
            username: server.authentication?.username,
            createdAt: server.createdAt
        )
    }

    private struct StoredSecurity {
        var isSecure: Bool
    }
}

// MARK: - Persistent Store

private actor ServerConfigFileStore {
    private let fileURL: URL
    private var cache: [StoredServerConfigRecord] = []
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async throws -> [StoredServerConfigRecord] {
        if cache.isEmpty {
            cache = try readFromDisk()
        }
        return cache
    }

    func upsert(_ record: StoredServerConfigRecord) async throws -> [StoredServerConfigRecord] {
        var next = try await load()
        if let index = next.firstIndex(where: { $0.id == record.id }) {
            next[index] = record
        } else {
            next.append(record)
        }
        try persist(next)
        cache = next
        return next
    }

    func delete(ids: [UUID]) async throws -> [StoredServerConfigRecord] {
        guard ids.isEmpty == false else {
            return try await load()
        }
        var next = try await load()
        next.removeAll { ids.contains($0.id) }
        try persist(next)
        cache = next
        return next
    }

    private func readFromDisk() throws -> [StoredServerConfigRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard data.isEmpty == false else { return [] }
            return try decoder.decode([StoredServerConfigRecord].self, from: data)
        } catch {
            throw ServerConfigRepositoryError.failedToLoad(error.localizedDescription)
        }
    }

    private func persist(_ records: [StoredServerConfigRecord]) throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ServerConfigRepositoryError.failedToPersist(error.localizedDescription)
        }
    }
}

// MARK: - In-memory store

private actor InMemoryServerConfigStore {
    private var servers: [ServerConfig]

    init(initial: [ServerConfig]) {
        self.servers = initial
    }

    func snapshot() -> [ServerConfig] {
        servers
    }

    func upsert(_ server: ServerConfig) -> [ServerConfig] {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
        return servers
    }

    func delete(ids: [UUID]) -> [ServerConfig] {
        guard ids.isEmpty == false else { return servers }
        servers.removeAll { ids.contains($0.id) }
        return servers
    }
}

// MARK: - Storage helpers

enum ServerConfigStoragePaths {
    static func defaultURL(fileManager: FileManager = .default) -> URL {
        let baseDirectory: URL
        if let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            baseDirectory = appSupport.appendingPathComponent("Remission", isDirectory: true)
        } else {
            baseDirectory =
                fileManager.urls(for: .documentDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("Remission", isDirectory: true)
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        return baseDirectory.appendingPathComponent("servers.json", isDirectory: false)
    }

    /// Синхронно читает сохранённые записи. Используется до инициализации TCA-окружения.
    static func loadSnapshot(fileURL: URL = defaultURL()) -> [StoredServerConfigRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard data.isEmpty == false else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([StoredServerConfigRecord].self, from: data)
        } catch {
            return []
        }
    }
}
