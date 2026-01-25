import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper Session")
struct TransmissionDomainMapperSessionTests {
    @Test("mapFreeSpaceBytes поддерживает int и double и бросает invalidType для строк")
    func mapFreeSpaceBytesSupportsNumericTypes() throws {
        // Это отдельная точка риска: сервер может вернуть число как int или double.
        let mapper = TransmissionDomainMapper()

        let intResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["size-bytes": .int(1_024)])
        )
        #expect(try mapper.mapFreeSpaceBytes(from: intResponse) == 1_024)

        let doubleResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["size-bytes": .double(2_048.9)])
        )
        #expect(try mapper.mapFreeSpaceBytes(from: doubleResponse) == 2_048)

        let invalidResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["size-bytes": .string("a lot")])
        )

        #expect(
            throws: DomainMappingError.invalidType(
                field: "size-bytes",
                expected: "int",
                context: "free-space"
            )
        ) {
            try mapper.mapFreeSpaceBytes(from: invalidResponse)
        }
    }

    @Test("mapSessionState маппит ключевые поля session-get и session-stats")
    func mapSessionStateMapsCoreFields() throws {
        // В этом тесте мы собираем минимально достаточный payload,
        // чтобы проверить wiring всех подсекций SessionState.
        let mapper = TransmissionDomainMapper()

        let sessionArguments: [String: AnyCodable] = [
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.3"),
            "download-dir": .string("/downloads"),
            "speed-limit-down-enabled": .bool(true),
            "speed-limit-down": .int(512),
            "speed-limit-up-enabled": .bool(false),
            "speed-limit-up": .int(128),
            "alt-speed-enabled": .bool(true),
            "alt-speed-down": .int(256),
            "alt-speed-up": .int(64),
            "download-queue-enabled": .bool(true),
            "download-queue-size": .int(3),
            "seed-queue-enabled": .bool(false),
            "seed-queue-size": .int(5),
            "queue-stalled-enabled": .bool(true),
            "queue-stalled-minutes": .int(30),
            "seedRatioLimited": .bool(true),
            "seedRatioLimit": .double(1.5)
        ]

        let statsArguments: [String: AnyCodable] = [
            "activeTorrentCount": .int(2),
            "pausedTorrentCount": .int(1),
            "torrentCount": .int(3),
            "downloadSpeed": .int(1_000_000),
            "uploadSpeed": .int(250_000),
            "cumulative-stats": .object([
                "filesAdded": .int(10),
                "downloadedBytes": .int(5_000),
                "uploadedBytes": .int(7_500),
                "sessionCount": .int(4),
                "secondsActive": .int(3600)
            ]),
            "current-stats": .object([
                "filesAdded": .int(2),
                "downloadedBytes": .int(1_000),
                "uploadedBytes": .int(500),
                "sessionCount": .int(1),
                "secondsActive": .int(600)
            ])
        ]

        let sessionResponse = TransmissionResponse(
            result: "success", arguments: .object(sessionArguments))
        let statsResponse = TransmissionResponse(
            result: "success", arguments: .object(statsArguments))

        let state = try mapper.mapSessionState(
            sessionResponse: sessionResponse,
            statsResponse: statsResponse,
            freeSpaceBytes: 9_999
        )

        #expect(state.rpc.rpcVersion == 17)
        #expect(state.rpc.rpcVersionMinimum == 14)
        #expect(state.rpc.serverVersion == "4.0.3")
        #expect(state.downloadDirectory == "/downloads")

        #expect(state.speedLimits.download.isEnabled)
        #expect(state.speedLimits.download.kilobytesPerSecond == 512)
        #expect(!state.speedLimits.upload.isEnabled)
        #expect(state.speedLimits.alternative.isEnabled)
        #expect(state.speedLimits.alternative.downloadKilobytesPerSecond == 256)

        #expect(state.queue.downloadLimit.isEnabled)
        #expect(state.queue.downloadLimit.count == 3)
        #expect(!state.queue.seedLimit.isEnabled)
        #expect(state.queue.considerStalled)
        #expect(state.queue.stalledMinutes == 30)

        #expect(state.seedRatioLimit.isEnabled)
        #expect(state.seedRatioLimit.value == 1.5)

        #expect(state.throughput.activeTorrentCount == 2)
        #expect(state.throughput.totalTorrentCount == 3)
        #expect(state.storage.freeBytes == 9_999)

        #expect(state.cumulativeStats.filesAdded == 10)
        #expect(state.currentStats.secondsActive == 600)
    }
}
