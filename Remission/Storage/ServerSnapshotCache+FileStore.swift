import Foundation

actor OfflineCacheFileStore {
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

    private typealias Metadata = [String: String]

    private func metadata(for key: OfflineCacheKey, extra: [String: String] = [:]) -> Metadata {
        var metadata: Metadata = [
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

enum ServerSnapshotStoragePaths {
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
