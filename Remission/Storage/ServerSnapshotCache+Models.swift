import CryptoKit
import Foundation

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

struct OfflineCacheEnvelope: Equatable, Codable, Sendable {
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
