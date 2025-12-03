import CryptoKit
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

    var latestUpdatedAt: Date? {
        [torrents?.updatedAt, session?.updatedAt].compactMap { $0 }.max()
    }
}

// MARK: - Offline Cache

struct OfflineCacheKey: Equatable, Codable, Sendable {
    var serverID: UUID
    var cacheFingerprint: String
    var rpcVersion: Int?

    func withRPCVersion(_ rpcVersion: Int?) -> OfflineCacheKey {
        OfflineCacheKey(
            serverID: serverID,
            cacheFingerprint: cacheFingerprint,
            rpcVersion: rpcVersion
        )
    }
}

struct OfflineCachePolicy: Equatable, Sendable {
    var timeToLive: TimeInterval
    var maxBytesPerServer: Int

    static var `default`: OfflineCachePolicy {
        OfflineCachePolicy(
            timeToLive: 30 * 60,
            maxBytesPerServer: 5 * 1_024 * 1_024
        )
    }
}

struct OfflineCacheClient: Sendable {
    var load: @Sendable () async throws -> ServerSnapshot?
    var updateTorrents: @Sendable ([Torrent]) async throws -> ServerSnapshot
    var updateSession: @Sendable (SessionState) async throws -> ServerSnapshot
    var clear: @Sendable () async throws -> Void
}

struct OfflineCacheRepository: Sendable {
    var policy: OfflineCachePolicy
    var client: @Sendable (_ key: OfflineCacheKey) -> OfflineCacheClient
    var clear: @Sendable (_ serverID: UUID) async throws -> Void
    var clearMultiple: @Sendable (_ serverIDs: [UUID]) async throws -> Void
}

#if canImport(ComposableArchitecture)
    extension OfflineCacheRepository: DependencyKey {
        static var liveValue: OfflineCacheRepository {
            @Dependency(\.dateProvider) var dateProvider
            @Dependency(\.appLogger) var appLogger
            let policy = OfflineCachePolicy.default
            let logger = appLogger.withCategory("offline-cache")
            let store = OfflineCacheFileStore(policy: policy, now: dateProvider.now, log: logger)

            return OfflineCacheRepository(
                policy: policy,
                client: { key in
                    OfflineCacheClient(
                        load: {
                            try await store.load(key: key)
                        },
                        updateTorrents: { torrents in
                            try await store.update(key: key, torrents: torrents)
                        },
                        updateSession: { session in
                            try await store.update(key: key, session: session)
                        },
                        clear: {
                            try await store.clear(serverID: key.serverID)
                        }
                    )
                },
                clear: { serverID in
                    try await store.clear(serverID: serverID)
                },
                clearMultiple: { serverIDs in
                    try await store.clearMultiple(serverIDs: serverIDs)
                }
            )
        }

        static var previewValue: OfflineCacheRepository {
            .inMemory()
        }

        static var testValue: OfflineCacheRepository {
            .inMemory()
        }
    }

    extension OfflineCacheRepository {
        static func inMemory(
            policy: OfflineCachePolicy = .default,
            now: @escaping @Sendable () -> Date = { Date() },
            logger: AppLogger = .noop
        ) -> OfflineCacheRepository {
            let store = InMemoryOfflineCacheStore(policy: policy, now: now, log: logger)
            return OfflineCacheRepository(
                policy: policy,
                client: { key in
                    OfflineCacheClient(
                        load: {
                            await store.load(key: key)
                        },
                        updateTorrents: { torrents in
                            try await store.update(key: key, torrents: torrents)
                        },
                        updateSession: { session in
                            try await store.update(key: key, session: session)
                        },
                        clear: {
                            await store.clear(serverID: key.serverID)
                        }
                    )
                },
                clear: { serverID in
                    await store.clear(serverID: serverID)
                },
                clearMultiple: { serverIDs in
                    await store.clearMultiple(serverIDs: serverIDs)
                }
            )
        }
    }

    extension DependencyValues {
        var offlineCacheRepository: OfflineCacheRepository {
            get { self[OfflineCacheRepository.self] }
            set { self[OfflineCacheRepository.self] = newValue }
        }
    }
#endif

// MARK: - File-backed store

private actor OfflineCacheFileStore {
    private let baseDirectory: URL
    private var cache: [UUID: OfflineCacheEnvelope] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let policy: OfflineCachePolicy
    private let now: @Sendable () -> Date
    private let log: AppLogger

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL = ServerSnapshotStoragePaths.defaultDirectory(),
        policy: OfflineCachePolicy,
        now: @escaping @Sendable () -> Date,
        log: AppLogger
    ) {
        self.baseDirectory = baseDirectory
        self.policy = policy
        self.now = now
        self.log = log
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(key: OfflineCacheKey) async throws -> ServerSnapshot? {
        guard let envelope = try await loadEnvelope(key: key, validateFreshness: true) else {
            log.debug("cache miss", metadata: metadata(for: key))
            return nil
        }
        log.debug("cache hit", metadata: metadata(for: key))
        return envelope.snapshot
    }

    func update(
        key: OfflineCacheKey,
        torrents: [Torrent]? = nil,
        session: SessionState? = nil
    ) async throws -> ServerSnapshot {
        var envelope =
            try await loadEnvelope(key: key, validateFreshness: false)
            ?? OfflineCacheEnvelope(key: key, snapshot: ServerSnapshot())
        envelope.key = key
        if let torrents {
            envelope.snapshot.torrents = CachedSnapshot(value: torrents, updatedAt: now())
        }
        if let session {
            envelope.snapshot.session = CachedSnapshot(value: session, updatedAt: now())
        }
        return try persist(envelope)
    }

    func clear(serverID: UUID) throws {
        cache[serverID] = nil
        let fileURL = makeFileURL(for: serverID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        log.debug("cache cleared", metadata: ["server_id": serverID.uuidString])
    }

    func clearMultiple(serverIDs: [UUID]) throws {
        for id in serverIDs {
            try clear(serverID: id)
        }
    }

    private func loadEnvelope(
        key: OfflineCacheKey,
        validateFreshness: Bool
    ) async throws -> OfflineCacheEnvelope? {
        if let cached = cache[key.serverID], cached.matches(key: key) {
            if validateFreshness == false || cached.isFresh(ttl: policy.timeToLive, now: now()) {
                return cached
            }
        }

        let fileURL = makeFileURL(for: key.serverID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard data.isEmpty == false else { return nil }
            let envelope = try decoder.decode(OfflineCacheEnvelope.self, from: data)
            guard envelope.matches(key: key) else {
                log.debug(
                    "cache invalidated due to fingerprint mismatch",
                    metadata: metadata(for: key)
                )
                try clear(serverID: key.serverID)
                return nil
            }
            cache[key.serverID] = envelope
            if validateFreshness, envelope.isFresh(ttl: policy.timeToLive, now: now()) == false {
                log.debug("cache expired", metadata: metadata(for: key))
                try clear(serverID: key.serverID)
                return nil
            }
            return envelope
        } catch {
            log.error(
                "failed to load cache",
                metadata: metadata(for: key, extra: ["error": error.localizedDescription])
            )
            try clear(serverID: key.serverID)
            throw OfflineCacheError.failedToLoad(error.localizedDescription)
        }
    }

    private func persist(_ envelope: OfflineCacheEnvelope) throws -> ServerSnapshot {
        do {
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(envelope)
            guard data.count <= policy.maxBytesPerServer else {
                try clear(serverID: envelope.key.serverID)
                throw OfflineCacheError.exceedsSizeLimit(
                    bytes: data.count,
                    limit: policy.maxBytesPerServer
                )
            }
            try data.write(to: makeFileURL(for: envelope.key.serverID), options: .atomic)
            cache[envelope.key.serverID] = envelope
            return envelope.snapshot
        } catch let error as OfflineCacheError {
            let bytes = (try? encoder.encode(envelope).count) ?? 0
            log.debug(
                "cache evicted due to size limit",
                metadata: metadata(
                    for: envelope.key,
                    extra: ["bytes": "\(bytes)"]
                )
            )
            throw error
        } catch {
            log.error(
                "failed to persist cache",
                metadata: metadata(
                    for: envelope.key,
                    extra: ["error": error.localizedDescription]
                )
            )
            throw OfflineCacheError.failedToPersist(error.localizedDescription)
        }
    }

    private func makeFileURL(for serverID: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(serverID.uuidString).json", isDirectory: false)
    }

    private func metadata(for key: OfflineCacheKey, extra: [String: String] = [:]) -> [String:
        String]
    {
        var metadata: [String: String] = [
            "server_id": key.serverID.uuidString,
            "fingerprint": key.cacheFingerprint
        ]
        if let version = key.rpcVersion {
            metadata["rpc_version"] = "\(version)"
        }
        for (key, value) in extra {
            metadata[key] = value
        }
        return metadata
    }
}

// MARK: - In-memory store (preview/test)

private actor InMemoryOfflineCacheStore {
    private var storage: [UUID: OfflineCacheEnvelope] = [:]
    private let policy: OfflineCachePolicy
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let log: AppLogger

    init(
        policy: OfflineCachePolicy,
        now: @escaping @Sendable () -> Date,
        log: AppLogger
    ) {
        self.policy = policy
        self.now = now
        self.log = log
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    func load(key: OfflineCacheKey) -> ServerSnapshot? {
        guard let envelope = storage[key.serverID] else { return nil }
        guard envelope.matches(key: key) else {
            storage[key.serverID] = nil
            log.debug(
                "cache invalidated due to fingerprint mismatch",
                metadata: [
                    "server_id": key.serverID.uuidString
                ])
            return nil
        }
        guard envelope.isFresh(ttl: policy.timeToLive, now: now()) else {
            storage[key.serverID] = nil
            log.debug("cache expired", metadata: ["server_id": key.serverID.uuidString])
            return nil
        }
        log.debug("cache hit", metadata: ["server_id": key.serverID.uuidString])
        return envelope.snapshot
    }

    func update(
        key: OfflineCacheKey,
        torrents: [Torrent]? = nil,
        session: SessionState? = nil
    ) throws -> ServerSnapshot {
        var envelope =
            storage[key.serverID]
            ?? OfflineCacheEnvelope(
                key: key,
                snapshot: ServerSnapshot()
            )
        envelope.key = key
        if let torrents {
            envelope.snapshot.torrents = CachedSnapshot(value: torrents, updatedAt: now())
        }
        if let session {
            envelope.snapshot.session = CachedSnapshot(value: session, updatedAt: now())
        }
        let data = try encoder.encode(envelope)
        guard data.count <= policy.maxBytesPerServer else {
            storage[key.serverID] = nil
            log.debug(
                "cache evicted due to size limit",
                metadata: ["server_id": key.serverID.uuidString]
            )
            throw OfflineCacheError.exceedsSizeLimit(
                bytes: data.count,
                limit: policy.maxBytesPerServer
            )
        }
        storage[key.serverID] = envelope
        log.debug("cache store", metadata: ["server_id": key.serverID.uuidString])
        return envelope.snapshot
    }

    func clear(serverID: UUID) {
        storage[serverID] = nil
        log.debug("cache cleared", metadata: ["server_id": serverID.uuidString])
    }

    func clearMultiple(serverIDs: [UUID]) {
        for id in serverIDs {
            clear(serverID: id)
        }
    }
}

// MARK: - Models & helpers

private struct OfflineCacheEnvelope: Equatable, Codable, Sendable {
    var key: OfflineCacheKey
    var snapshot: ServerSnapshot

    func matches(key: OfflineCacheKey) -> Bool {
        guard self.key.cacheFingerprint == key.cacheFingerprint else {
            return false
        }

        if let expectedVersion = key.rpcVersion {
            guard self.key.rpcVersion == expectedVersion else { return false }
        }

        return true
    }

    func isFresh(ttl: TimeInterval, now: Date) -> Bool {
        guard let updatedAt = snapshot.latestUpdatedAt else {
            return false
        }
        return now.timeIntervalSince(updatedAt) <= ttl
    }
}

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

enum OfflineCacheError: Error, LocalizedError, Sendable {
    case failedToLoad(String)
    case failedToPersist(String)
    case exceedsSizeLimit(bytes: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .failedToLoad(let message):
            return "Не удалось загрузить кеш снапшота: \(message)"
        case .failedToPersist(let message):
            return "Не удалось сохранить кеш снапшота: \(message)"
        case .exceedsSizeLimit(let bytes, let limit):
            return "Кеш снапшота превышает лимит \(limit) байт (получено \(bytes))."
        }
    }
}

// MARK: - Fingerprint helpers

extension OfflineCacheKey {
    static func make(
        server: ServerConfig,
        credentialsFingerprint: String,
        rpcVersion: Int?
    ) -> OfflineCacheKey {
        let transport: String = server.isSecure ? "https" : "http"
        let username: String = server.authentication?.username.lowercased() ?? ""
        let host: String = server.connection.host.lowercased()
        let fingerprint =
            "\(host):\(server.connection.port):\(transport):\(username)#\(credentialsFingerprint)"
        return OfflineCacheKey(
            serverID: server.id,
            cacheFingerprint: fingerprint,
            rpcVersion: rpcVersion
        )
    }

    static func credentialsFingerprint(
        credentialsKey: TransmissionServerCredentialsKey?,
        password: String?
    ) -> String {
        guard let credentialsKey else {
            return "anonymous"
        }
        let base = credentialsKey.accountIdentifier
        guard let password else {
            return "no-password:\(base)"
        }
        let digest = SHA256.hash(data: Data("\(base):\(password)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
