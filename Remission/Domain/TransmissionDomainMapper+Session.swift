import Foundation

extension TransmissionDomainMapper {
    func mapSessionState(
        sessionResponse: TransmissionResponse,
        statsResponse: TransmissionResponse
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
        let downloadDirectory: String = try requireString(
            "download-dir",
            in: sessionArguments,
            context: "session-get"
        )

        let speedLimits: SessionState.SpeedLimits = makeSpeedLimits(from: sessionArguments)
        let queue: SessionState.Queue = makeQueue(from: sessionArguments)
        let throughput: SessionState.Throughput = makeThroughput(from: statsArguments)

        let cumulativeStats: SessionState.LifetimeStats = try mapLifetimeStats(
            from: statsArguments,
            field: "cumulative-stats",
            context: "session-stats"
        )
        let currentStats: SessionState.LifetimeStats = try mapLifetimeStats(
            from: statsArguments,
            field: "current-stats",
            context: "session-stats"
        )

        return SessionState(
            rpc: rpcInfo,
            downloadDirectory: downloadDirectory,
            speedLimits: speedLimits,
            queue: queue,
            throughput: throughput,
            cumulativeStats: cumulativeStats,
            currentStats: currentStats
        )
    }

    func makeSpeedLimits(
        from dict: [String: AnyCodable]
    ) -> SessionState.SpeedLimits {
        SessionState.SpeedLimits(
            download: .init(
                isEnabled: boolValue(
                    "speed-limit-down-enabled",
                    in: dict
                ) ?? false,
                kilobytesPerSecond: intValue(
                    "speed-limit-down",
                    in: dict
                ) ?? 0
            ),
            upload: .init(
                isEnabled: boolValue(
                    "speed-limit-up-enabled",
                    in: dict
                ) ?? false,
                kilobytesPerSecond: intValue(
                    "speed-limit-up",
                    in: dict
                ) ?? 0
            ),
            alternative: .init(
                isEnabled: boolValue("alt-speed-enabled", in: dict) ?? false,
                downloadKilobytesPerSecond: intValue(
                    "alt-speed-down",
                    in: dict
                ) ?? 0,
                uploadKilobytesPerSecond: intValue(
                    "alt-speed-up",
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
                    "download-queue-enabled",
                    in: dict
                ) ?? false,
                count: intValue(
                    "download-queue-size",
                    in: dict
                ) ?? 0
            ),
            seedLimit: .init(
                isEnabled: boolValue(
                    "seed-queue-enabled",
                    in: dict
                ) ?? false,
                count: intValue(
                    "seed-queue-size",
                    in: dict
                ) ?? 0
            ),
            considerStalled: boolValue(
                "queue-stalled-enabled",
                in: dict
            ) ?? false,
            stalledMinutes: intValue(
                "queue-stalled-minutes",
                in: dict
            ) ?? 0
        )
    }

    func makeRPCInfo(
        from dict: [String: AnyCodable]
    ) throws -> SessionState.RPC {
        let version: String = try requireString(
            "version",
            in: dict,
            context: "session-get"
        )
        return SessionState.RPC(
            rpcVersion: try requireInt(
                "rpc-version",
                in: dict,
                context: "session-get"
            ),
            rpcVersionMinimum: try requireInt(
                "rpc-version-minimum",
                in: dict,
                context: "session-get"
            ),
            serverVersion: version
        )
    }

    func makeThroughput(
        from dict: [String: AnyCodable]
    ) -> SessionState.Throughput {
        SessionState.Throughput(
            activeTorrentCount: intValue(
                "activeTorrentCount",
                in: dict
            ) ?? 0,
            pausedTorrentCount: intValue(
                "pausedTorrentCount",
                in: dict
            ) ?? 0,
            totalTorrentCount: intValue(
                "torrentCount",
                in: dict
            ) ?? 0,
            downloadSpeed: intValue(
                "downloadSpeed",
                in: dict
            ) ?? 0,
            uploadSpeed: intValue(
                "uploadSpeed",
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
            filesAdded: intValue("filesAdded", in: statsDict) ?? 0,
            downloadedBytes: int64Value("downloadedBytes", in: statsDict),
            uploadedBytes: int64Value("uploadedBytes", in: statsDict),
            sessionCount: intValue("sessionCount", in: statsDict) ?? 0,
            secondsActive: intValue("secondsActive", in: statsDict) ?? 0
        )
    }

    func int64Value(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Int64 {
        if let int = dict[field]?.intValue {
            return Int64(int)
        }
        if let double = dict[field]?.doubleValue {
            return Int64(double)
        }
        return 0
    }
}
