import Foundation

#if canImport(ComposableArchitecture)
    import Dependencies
#endif

extension SessionRepository {
    static func fetchSessionState(
        transmissionClient: TransmissionClientDependency,
        mapper: TransmissionDomainMapper,
        cacheState: @Sendable (SessionState) async throws -> Void
    ) async throws -> SessionState {
        let session = try await transmissionClient.sessionGet()
        let stats = try await transmissionClient.sessionStats()
        let sessionArguments = try mapper.arguments(
            from: session,
            context: "session-get"
        )
        let downloadDirectory = try mapper.requireString(
            "download-dir",
            in: sessionArguments,
            context: "session-get"
        )
        let freeSpaceBytes: Int64
        do {
            let freeSpaceResponse = try await transmissionClient.freeSpace(downloadDirectory)
            freeSpaceBytes = try mapper.mapFreeSpaceBytes(from: freeSpaceResponse)
        } catch {
            freeSpaceBytes = 0
        }
        let state = try mapper.mapSessionState(
            sessionResponse: session,
            statsResponse: stats,
            freeSpaceBytes: freeSpaceBytes
        )
        try await cacheState(state)
        return state
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func makeSessionSetArguments(
        update: SessionRepository.SessionUpdate
    ) -> AnyCodable? {
        var dict: [String: AnyCodable] = [:]

        if let speedLimits = update.speedLimits {
            if let download = speedLimits.download {
                dict["speed-limit-down-enabled"] = .bool(download.isEnabled)
                dict["speed-limit-down"] = .int(download.kilobytesPerSecond)
            }
            if let upload = speedLimits.upload {
                dict["speed-limit-up-enabled"] = .bool(upload.isEnabled)
                dict["speed-limit-up"] = .int(upload.kilobytesPerSecond)
            }
            if let alt = speedLimits.alternative {
                dict["alt-speed-enabled"] = .bool(alt.isEnabled)
                dict["alt-speed-down"] = .int(alt.downloadKilobytesPerSecond)
                dict["alt-speed-up"] = .int(alt.uploadKilobytesPerSecond)
            }
        }

        if let queue = update.queue {
            if let downloadLimit = queue.downloadLimit {
                dict["download-queue-enabled"] = .bool(downloadLimit.isEnabled)
                dict["download-queue-size"] = .int(downloadLimit.count)
            }
            if let seedLimit = queue.seedLimit {
                dict["seed-queue-enabled"] = .bool(seedLimit.isEnabled)
                dict["seed-queue-size"] = .int(seedLimit.count)
            }
            if let considerStalled = queue.considerStalled {
                dict["queue-stalled-enabled"] = .bool(considerStalled)
            }
            if let stalledMinutes = queue.stalledMinutes {
                dict["queue-stalled-minutes"] = .int(stalledMinutes)
            }
        }

        if let seedRatioLimit = update.seedRatioLimit {
            dict["seedRatioLimited"] = .bool(seedRatioLimit.isEnabled)
            if seedRatioLimit.isEnabled {
                dict["seedRatioLimit"] = .double(seedRatioLimit.value)
            }
        }

        guard dict.isEmpty == false else { return nil }
        return .object(dict)
    }
}

extension TransmissionHandshakeResult {
    func asSessionRepositoryHandshake() -> SessionRepository.Handshake {
        SessionRepository.Handshake(
            sessionID: sessionID,
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumSupportedRpcVersion,
            serverVersionDescription: serverVersionDescription,
            isCompatible: isCompatible
        )
    }
}
