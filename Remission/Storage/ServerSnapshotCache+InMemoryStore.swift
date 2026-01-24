import Foundation

actor InMemoryOfflineCacheStore {
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
