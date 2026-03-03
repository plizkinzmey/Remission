import Foundation

extension TransmissionDomainMapper {
    func mapSessionState(
        sessionResponse: TransmissionResponse,
        statsResponse: TransmissionResponse,
        freeSpaceBytes: Int64
    ) throws -> SessionState {
        let sessionArguments: [String: AnyCodable] = try arguments(
            from: sessionResponse,
            context: "session-get"
        )
        let statsArguments: [String: AnyCodable] = try arguments(
            from: statsResponse,
            context: "session-stats"
        )

        let rpcInfo: SessionState.RPC = try makeRPCInfo(from: sessionArguments)
        let downloadDirectory = stringValue(
            aliases: ["download_dir", "download-dir"],
            in: sessionArguments
        ) ?? ""

        let speedLimits: SessionState.SpeedLimits = makeSpeedLimits(from: sessionArguments)
        let queue: SessionState.Queue = makeQueue(from: sessionArguments)
        let seedRatioLimit: SessionState.SeedRatioLimit = makeSeedRatioLimit(
            from: sessionArguments
        )
        let throughput: SessionState.Throughput = makeThroughput(from: statsArguments)
        let storage = SessionState.Storage(freeBytes: freeSpaceBytes)

        let cumulativeStats: SessionState.LifetimeStats = try mapLifetimeStats(
            from: statsArguments,
            field: statsArguments["cumulative_stats"] == nil ? "cumulative-stats" : "cumulative_stats",
            context: "session-stats"
        )
        let currentStats: SessionState.LifetimeStats = try mapLifetimeStats(
            from: statsArguments,
            field: statsArguments["current_stats"] == nil ? "current-stats" : "current_stats",
            context: "session-stats"
        )

        return SessionState(
            rpc: rpcInfo,
            downloadDirectory: downloadDirectory,
            speedLimits: speedLimits,
            queue: queue,
            seedRatioLimit: seedRatioLimit,
            throughput: throughput,
            storage: storage,
            cumulativeStats: cumulativeStats,
            currentStats: currentStats
        )
    }

    func mapFreeSpaceBytes(
        from response: TransmissionResponse
    ) throws -> Int64 {
        let arguments: [String: AnyCodable] = try arguments(
            from: response,
            context: "free-space"
        )
        let value = try requireField(
            arguments["size_bytes"] == nil ? "size-bytes" : "size_bytes",
            in: arguments,
            context: "free-space"
        )
        if let int = value.intValue {
            return Int64(int)
        }
        if let double = value.doubleValue {
            return Int64(double)
        }
        throw DomainMappingError.invalidType(
            field: "size-bytes",
            expected: "int",
            context: "free-space"
        )
    }

    func makeSpeedLimits(
        from dict: [String: AnyCodable]
    ) -> SessionState.SpeedLimits {
        SessionState.SpeedLimits(
            download: .init(
                isEnabled: boolValue(
                    aliases: ["speed_limit_down_enabled", "speed-limit-down-enabled"],
                    in: dict
                ) ?? false,
                kilobytesPerSecond: intValue(
                    aliases: ["speed_limit_down", "speed-limit-down"],
                    in: dict
                ) ?? 0
            ),
            upload: .init(
                isEnabled: boolValue(
                    aliases: ["speed_limit_up_enabled", "speed-limit-up-enabled"],
                    in: dict
                ) ?? false,
                kilobytesPerSecond: intValue(
                    aliases: ["speed_limit_up", "speed-limit-up"],
                    in: dict
                ) ?? 0
            ),
            alternative: .init(
                isEnabled: boolValue(aliases: ["alt_speed_enabled", "alt-speed-enabled"], in: dict)
                    ?? false,
                downloadKilobytesPerSecond: intValue(
                    aliases: ["alt_speed_down", "alt-speed-down"],
                    in: dict
                ) ?? 0,
                uploadKilobytesPerSecond: intValue(
                    aliases: ["alt_speed_up", "alt-speed-up"],
                    in: dict
                ) ?? 0
            )
        )
    }

    func makeQueue(
        from dict: [String: AnyCodable]
    ) -> SessionState.Queue {
        SessionState.Queue(
            downloadLimit: .init(
                isEnabled: boolValue(
                    aliases: ["download_queue_enabled", "download-queue-enabled"],
                    in: dict
                ) ?? false,
                count: intValue(
                    aliases: ["download_queue_size", "download-queue-size"],
                    in: dict
                ) ?? 0
            ),
            seedLimit: .init(
                isEnabled: boolValue(
                    aliases: ["seed_queue_enabled", "seed-queue-enabled"],
                    in: dict
                ) ?? false,
                count: intValue(
                    aliases: ["seed_queue_size", "seed-queue-size"],
                    in: dict
                ) ?? 0
            ),
            considerStalled: boolValue(
                aliases: ["queue_stalled_enabled", "queue-stalled-enabled"],
                in: dict
            ) ?? false,
            stalledMinutes: intValue(
                aliases: ["queue_stalled_minutes", "queue-stalled-minutes"],
                in: dict
            ) ?? 0
        )
    }

    func makeSeedRatioLimit(
        from dict: [String: AnyCodable]
    ) -> SessionState.SeedRatioLimit {
        let isEnabled = boolValue(aliases: ["seed_ratio_limited", "seedRatioLimited"], in: dict)
            ?? false
        let value = doubleValue(aliases: ["seed_ratio_limit", "seedRatioLimit"], in: dict) ?? 0.0
        return SessionState.SeedRatioLimit(isEnabled: isEnabled, value: value)
    }

    func makeRPCInfo(
        from dict: [String: AnyCodable]
    ) throws -> SessionState.RPC {
        let version = stringValue(aliases: ["version"], in: dict) ?? ""
        let rpcVersion = intValue(
            aliases: ["rpc_version", "rpc-version"],
            in: dict
        )
        let rpcVersionMinimum = intValue(
            aliases: ["rpc_version_minimum", "rpc-version-minimum"],
            in: dict
        )
        guard let rpcVersion, let rpcVersionMinimum else {
            throw DomainMappingError.missingField(
                field: "rpc_version|rpc-version",
                context: "session-get"
            )
        }
        return SessionState.RPC(
            rpcVersion: rpcVersion,
            rpcVersionMinimum: rpcVersionMinimum,
            serverVersion: version
        )
    }

    func makeThroughput(
        from dict: [String: AnyCodable]
    ) -> SessionState.Throughput {
        SessionState.Throughput(
            activeTorrentCount: intValue(
                aliases: ["active_torrent_count", "activeTorrentCount"],
                in: dict
            ) ?? 0,
            pausedTorrentCount: intValue(
                aliases: ["paused_torrent_count", "pausedTorrentCount"],
                in: dict
            ) ?? 0,
            totalTorrentCount: intValue(
                aliases: ["torrent_count", "torrentCount"],
                in: dict
            ) ?? 0,
            downloadSpeed: intValue(
                aliases: ["download_speed", "downloadSpeed"],
                in: dict
            ) ?? 0,
            uploadSpeed: intValue(
                aliases: ["upload_speed", "uploadSpeed"],
                in: dict
            ) ?? 0
        )
    }

    func mapLifetimeStats(
        from dict: [String: AnyCodable],
        field: String,
        context: String
    ) throws -> SessionState.LifetimeStats {
        guard let statsValue = dict[field] else {
            throw DomainMappingError.missingField(field: field, context: context)
        }

        guard case .object(let statsDict) = statsValue else {
            throw DomainMappingError.invalidType(
                field: field,
                expected: "object",
                context: context
            )
        }

        return SessionState.LifetimeStats(
            filesAdded: intValue(aliases: ["files_added", "filesAdded"], in: statsDict) ?? 0,
            downloadedBytes: int64Value(
                aliases: ["downloaded_bytes", "downloadedBytes"],
                in: statsDict
            ),
            uploadedBytes: int64Value(aliases: ["uploaded_bytes", "uploadedBytes"], in: statsDict),
            sessionCount: intValue(aliases: ["session_count", "sessionCount"], in: statsDict)
                ?? 0,
            secondsActive: intValue(aliases: ["seconds_active", "secondsActive"], in: statsDict)
                ?? 0
        )
    }
}
