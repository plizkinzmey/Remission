import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Универсальный контейнер кешированного значения с отметкой времени.
struct CachedSnapshot<Value: Equatable & Codable & Sendable>: Equatable, Codable, Sendable {
    var value: Value
    var updatedAt: Date
}

/// Снэпшот состояния сервера: список торрентов и состояние сессии.
struct ServerSnapshot: Equatable, Codable, Sendable {
    var torrents: CachedSnapshot<[Torrent]>?
    var session: CachedSnapshot<SessionState>?

    init(
        torrents: CachedSnapshot<[Torrent]>? = nil,
        session: CachedSnapshot<SessionState>? = nil
    ) {
        self.torrents = torrents
        self.session = session
    }
}

/// Клиент, привязанный к конкретному серверу (по UUID).
struct ServerSnapshotClient: Sendable {
    var load: @Sendable () async throws -> ServerSnapshot?
    var updateTorrents: @Sendable ([Torrent]) async throws -> ServerSnapshot
    var updateSession: @Sendable (SessionState) async throws -> ServerSnapshot
    var clear: @Sendable () async throws -> Void
}

#if canImport(ComposableArchitecture)
    struct ServerSnapshotCache: Sendable {
        var client: @Sendable (_ serverID: UUID) -> ServerSnapshotClient
    }

    extension ServerSnapshotCache: DependencyKey {
        static var liveValue: Self {
            @Dependency(\.dateProvider) var dateProvider
            let store = ServerSnapshotFileStore(now: dateProvider.now)
            return Self { serverID in
                ServerSnapshotClient(
                    load: {
                        try await store.load(serverID: serverID)
                    },
                    updateTorrents: { torrents in
                        try await store.update(serverID: serverID, torrents: torrents)
                    },
                    updateSession: { session in
                        try await store.update(serverID: serverID, session: session)
                    },
                    clear: {
                        try await store.clear(serverID: serverID)
                    }
                )
            }
        }

        static var previewValue: Self {
            .inMemory()
        }

        static var testValue: Self {
            .inMemory()
        }
    }

    extension ServerSnapshotCache {
        static func inMemory(
            now: @escaping @Sendable () -> Date = { Date() }
        ) -> ServerSnapshotCache {
            let store = InMemoryServerSnapshotStore(now: now)
            return ServerSnapshotCache { serverID in
                ServerSnapshotClient(
                    load: {
                        await store.load(serverID: serverID)
                    },
                    updateTorrents: { torrents in
                        await store.update(serverID: serverID, torrents: torrents)
                    },
                    updateSession: { session in
                        await store.update(serverID: serverID, session: session)
                    },
                    clear: {
                        await store.clear(serverID: serverID)
                    }
                )
            }
        }
    }

    extension DependencyValues {
        var serverSnapshotCache: ServerSnapshotCache {
            get { self[ServerSnapshotCache.self] }
            set { self[ServerSnapshotCache.self] = newValue }
        }
    }
#endif

// MARK: - Live File Store

private actor ServerSnapshotFileStore {
    private let baseDirectory: URL
    private var cache: [UUID: ServerSnapshot] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL = ServerSnapshotStoragePaths.defaultDirectory(),
        now: @escaping @Sendable () -> Date
    ) {
        self.baseDirectory = baseDirectory
        self.now = now
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(serverID: UUID) async throws -> ServerSnapshot? {
        if let cached = cache[serverID] {
            return cached
        }
        let fileURL = makeFileURL(for: serverID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard data.isEmpty == false else { return nil }
            let snapshot = try decoder.decode(ServerSnapshot.self, from: data)
            cache[serverID] = snapshot
            return snapshot
        } catch {
            throw ServerSnapshotCacheError.failedToLoad(error.localizedDescription)
        }
    }

    func update(serverID: UUID, torrents: [Torrent]) async throws -> ServerSnapshot {
        var snapshot = try await load(serverID: serverID) ?? ServerSnapshot()
        snapshot.torrents = CachedSnapshot(value: torrents, updatedAt: now())
        return try persist(snapshot, serverID: serverID)
    }

    func update(serverID: UUID, session: SessionState) async throws -> ServerSnapshot {
        var snapshot = try await load(serverID: serverID) ?? ServerSnapshot()
        snapshot.session = CachedSnapshot(value: session, updatedAt: now())
        return try persist(snapshot, serverID: serverID)
    }

    func clear(serverID: UUID) throws {
        cache[serverID] = nil
        let fileURL = makeFileURL(for: serverID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func persist(
        _ snapshot: ServerSnapshot,
        serverID: UUID
    ) throws -> ServerSnapshot {
        do {
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: makeFileURL(for: serverID), options: .atomic)
            cache[serverID] = snapshot
            return snapshot
        } catch {
            throw ServerSnapshotCacheError.failedToPersist(error.localizedDescription)
        }
    }

    private func makeFileURL(for serverID: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(serverID.uuidString).json", isDirectory: false)
    }
}

// MARK: - In-Memory Store (preview/test)

private actor InMemoryServerSnapshotStore {
    private var storage: [UUID: ServerSnapshot] = [:]
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    func load(serverID: UUID) -> ServerSnapshot? {
        storage[serverID]
    }

    func update(serverID: UUID, torrents: [Torrent]) -> ServerSnapshot {
        var snapshot = storage[serverID] ?? ServerSnapshot()
        snapshot.torrents = CachedSnapshot(value: torrents, updatedAt: now())
        storage[serverID] = snapshot
        return snapshot
    }

    func update(serverID: UUID, session: SessionState) -> ServerSnapshot {
        var snapshot = storage[serverID] ?? ServerSnapshot()
        snapshot.session = CachedSnapshot(value: session, updatedAt: now())
        storage[serverID] = snapshot
        return snapshot
    }

    func clear(serverID: UUID) {
        storage[serverID] = nil
    }
}

// MARK: - Paths & Errors

private enum ServerSnapshotStoragePaths {
    static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        let baseDirectory: URL
        if let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            baseDirectory = appSupport.appendingPathComponent(
                "Remission/Snapshots", isDirectory: true)
        } else {
            baseDirectory =
                fileManager.urls(for: .documentDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("Remission/Snapshots", isDirectory: true)
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        return baseDirectory
    }
}

enum ServerSnapshotCacheError: Error, LocalizedError, Sendable {
    case failedToLoad(String)
    case failedToPersist(String)

    var errorDescription: String? {
        switch self {
        case .failedToLoad(let message):
            return "Не удалось загрузить кеш снапшота: \(message)"
        case .failedToPersist(let message):
            return "Не удалось сохранить кеш снапшота: \(message)"
        }
    }
}
