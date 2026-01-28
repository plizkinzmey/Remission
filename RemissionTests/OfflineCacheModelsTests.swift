import Foundation
import Testing

@testable import Remission

@Suite("Offline Cache Models Tests")
struct OfflineCacheModelsTests {
    // Проверяет вычисление latestUpdatedAt как максимальной из дат снапшота.
    @Test
    func latestUpdatedAtUsesMostRecentSnapshotDate() {
        let torrentsDate = Date(timeIntervalSince1970: 10)
        let sessionDate = Date(timeIntervalSince1970: 20)
        let snapshot = ServerSnapshot(
            torrents: CachedSnapshot(value: [Torrent.previewDownloading], updatedAt: torrentsDate),
            session: CachedSnapshot(value: .previewActive, updatedAt: sessionDate)
        )

        #expect(snapshot.latestUpdatedAt == sessionDate)
    }

    // Проверяет правила matches по fingerprint и rpcVersion.
    @Test
    func envelopeMatchesFingerprintAndOptionalRPCVersion() {
        let key = OfflineCacheKey(serverID: UUID(), cacheFingerprint: "fp", rpcVersion: 1)
        let envelope = OfflineCacheEnvelope(key: key, snapshot: ServerSnapshot())

        #expect(envelope.matches(key: key))
        #expect(envelope.matches(key: key.withRPCVersion(nil)))

        let otherVersion = OfflineCacheKey(
            serverID: key.serverID,
            cacheFingerprint: "fp",
            rpcVersion: 2
        )
        #expect(envelope.matches(key: otherVersion) == false)
    }

    // Проверяет isFresh с учетом ttl и отсутствия дат.
    @Test
    func envelopeFreshnessRespectsTTLAndMissingDates() {
        let now = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 90)
        let envelope = OfflineCacheEnvelope(
            key: OfflineCacheKey(serverID: UUID(), cacheFingerprint: "fp", rpcVersion: nil),
            snapshot: ServerSnapshot(
                torrents: CachedSnapshot(value: [Torrent.previewDownloading], updatedAt: updatedAt),
                session: nil
            )
        )

        #expect(envelope.isFresh(ttl: 15, now: now))
        #expect(envelope.isFresh(ttl: 5, now: now) == false)

        let emptyEnvelope = OfflineCacheEnvelope(key: envelope.key, snapshot: ServerSnapshot())
        #expect(emptyEnvelope.isFresh(ttl: 100, now: now) == false)
    }

    // Проверяет credentialsFingerprint для разных сценариев.
    @Test
    func credentialsFingerprintCoversAnonymousNoPasswordAndPassword() {
        let anonymous = OfflineCacheKey.credentialsFingerprint(credentialsKey: nil, password: nil)
        #expect(anonymous == "anonymous")

        let key = TransmissionServerCredentialsKey(
            host: "Host",
            port: 1,
            isSecure: true,
            username: "User"
        )
        let noPassword = OfflineCacheKey.credentialsFingerprint(credentialsKey: key, password: nil)
        #expect(noPassword.contains("no-password:"))
        #expect(noPassword.contains(key.accountIdentifier))

        let fp1 = OfflineCacheKey.credentialsFingerprint(credentialsKey: key, password: "p1")
        let fp2 = OfflineCacheKey.credentialsFingerprint(credentialsKey: key, password: "p1")
        let fp3 = OfflineCacheKey.credentialsFingerprint(credentialsKey: key, password: "p2")
        #expect(fp1 == fp2)
        #expect(fp1 != fp3)
        #expect(fp1.count == 64)
    }

    // Проверяет, что make(server:) нормализует регистр host/username в fingerprint.
    @Test
    func makeKeyNormalizesFingerprintComponents() {
        let server = ServerConfig(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Test",
            connection: .init(host: "NAS.LOCAL", port: 9091, path: "/rpc"),
            security: .https(allowUntrustedCertificates: false),
            authentication: .init(username: "Admin"),
            createdAt: Date(timeIntervalSince1970: 1)
        )

        let key = OfflineCacheKey.make(
            server: server,
            credentialsFingerprint: "cred",
            rpcVersion: 17
        )
        #expect(key.cacheFingerprint.contains("nas.local"))
        #expect(key.cacheFingerprint.contains("admin"))
        #expect(key.cacheFingerprint.contains("https"))
        #expect(key.rpcVersion == 17)
    }
}
