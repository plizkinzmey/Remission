import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

// MARK: - Parser Dependency

#if canImport(ComposableArchitecture)
    @DependencyClient
    struct TorrentDetailParserDependency: Sendable {
        var parse: @Sendable (TransmissionResponse) throws -> Torrent
    }

    extension TorrentDetailParserDependency {
        fileprivate static let placeholder: Self = Self(
            parse: { _ in throw TorrentDetailParserDependencyError.notConfigured("parse") }
        )
    }

    enum TorrentDetailParserDependencyError: Error, LocalizedError, Sendable {
        case notConfigured(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let name):
                return
                    "TorrentDetailParserDependency.\(name) is not configured for this environment."
            }
        }
    }

    extension TorrentDetailParserDependency: DependencyKey {
        static let liveValue: Self = Self { response in
            try TorrentDetailParser().parse(response)
        }

        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        @preconcurrency var torrentDetailParser: TorrentDetailParserDependency {
            get { self[TorrentDetailParserDependency.self] }
            set { self[TorrentDetailParserDependency.self] = newValue }
        }
    }
#endif

enum TorrentDetailParserError: Error, LocalizedError, Equatable {
    case missingTorrentData

    var errorDescription: String? {
        switch self {
        case .missingTorrentData:
            return "Ошибка парсирования ответа сервера"
        }
    }
}

// MARK: - Parser Implementation

struct TorrentDetailParser: Sendable {
    func parse(_ response: TransmissionResponse) throws -> Torrent {
        guard let torrentDict = extractTorrentDictionary(from: response) else {
            throw TorrentDetailParserError.missingTorrentData
        }

        let identifier: Int = intValue(for: "id", in: torrentDict) ?? 0
        let name: String = stringValue(for: "name", in: torrentDict) ?? ""
        let statusValue: Int = intValue(for: "status", in: torrentDict) ?? 0
        let status: Torrent.Status = Torrent.Status(rawValue: statusValue) ?? .stopped

        let summary: Torrent.Summary = makeSummary(from: torrentDict)
        let details: Torrent.Details = makeDetails(from: torrentDict)

        return Torrent(
            id: Torrent.Identifier(rawValue: identifier),
            name: name,
            status: status,
            summary: summary,
            details: details
        )
    }

    private func extractTorrentDictionary(
        from response: TransmissionResponse
    ) -> [String: AnyCodable]? {
        guard let arguments = response.arguments,
            case .object(let dict) = arguments,
            let torrentsData = dict["torrents"],
            case .array(let torrentsArray) = torrentsData,
            let torrentObj = torrentsArray.first,
            case .object(let torrentDict) = torrentObj
        else {
            return nil
        }

        return torrentDict
    }

    private func percentDoneValue(in dict: [String: AnyCodable]) -> Double? {
        guard let percent = dict["percentDone"] else {
            return nil
        }
        switch percent {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value) / 100.0
        default:
            return nil
        }
    }

    private func parsePeers(from dict: [String: AnyCodable]) -> [PeerSource] {
        guard let peersValue = dict["peersFrom"], case .object(let peersDict) = peersValue else {
            return []
        }

        return peersDict.compactMap { key, value in
            if case .int(let count) = value {
                return PeerSource(name: key, count: count)
            }
            return nil
        }
        .sorted { lhs, rhs in lhs.count > rhs.count }
    }

    private func parseFiles(from dict: [String: AnyCodable]) -> [TorrentFile] {
        guard let filesValue = dict["files"], case .array(let filesArray) = filesValue else {
            return []
        }

        return filesArray.enumerated().compactMap { index, fileData in
            guard case .object(let fileDict) = fileData,
                let name = stringValue(for: "name", in: fileDict),
                let length = intValue(for: "length", in: fileDict),
                let completed = intValue(for: "bytesCompleted", in: fileDict)
            else {
                return nil
            }

            let priority: Int = intValue(for: "priority", in: fileDict) ?? 1
            let wanted: Bool = boolValue(for: "wanted", in: fileDict) ?? true

            return TorrentFile(
                index: index,
                name: name,
                length: length,
                bytesCompleted: completed,
                priority: priority,
                wanted: wanted
            )
        }
    }

    private func parseTrackers(from dict: [String: AnyCodable]) -> [TorrentTracker] {
        guard let trackersValue = dict["trackers"], case .array(let trackersArray) = trackersValue
        else {
            return []
        }

        return trackersArray.compactMap { trackerData in
            guard case .object(let trackerDict) = trackerData,
                let announce = stringValue(for: "announce", in: trackerDict)
            else {
                return nil
            }

            let tier: Int = intValue(for: "tier", in: trackerDict) ?? 0
            let trackerId: Int =
                intValue(for: "id", in: trackerDict)
                ?? intValue(for: "trackerId", in: trackerDict)
                ?? tier
            return TorrentTracker(id: trackerId, announce: announce, tier: tier)
        }
    }

    private func parseTrackerStats(from dict: [String: AnyCodable]) -> [TrackerStat] {
        guard let statsValue = dict["trackerStats"], case .array(let statsArray) = statsValue else {
            return []
        }

        return statsArray.compactMap { statData in
            guard case .object(let statDict) = statData else {
                return nil
            }

            let trackerId: Int =
                intValue(for: "id", in: statDict)
                ?? intValue(for: "trackerId", in: statDict)
                ?? 0

            let announceResult: String = stringValue(for: "lastAnnounceResult", in: statDict) ?? ""
            let downloadCount: Int = intValue(for: "downloadCount", in: statDict) ?? 0
            let leecherCount: Int = intValue(for: "leecherCount", in: statDict) ?? 0
            let seederCount: Int = intValue(for: "seederCount", in: statDict) ?? 0

            return TrackerStat(
                trackerId: trackerId,
                lastAnnounceResult: announceResult,
                downloadCount: downloadCount,
                leecherCount: leecherCount,
                seederCount: seederCount
            )
        }
    }

    private func intValue(for key: String, in dict: [String: AnyCodable]) -> Int? {
        guard let value = dict[key] else { return nil }
        if case .int(let intValue) = value {
            return intValue
        }
        return nil
    }

    private func doubleValue(for key: String, in dict: [String: AnyCodable]) -> Double? {
        guard let value = dict[key] else { return nil }
        if case .double(let doubleValue) = value {
            return doubleValue
        }
        if case .int(let intValue) = value {
            return Double(intValue)
        }
        return nil
    }

    private func makeSummary(from dict: [String: AnyCodable]) -> Torrent.Summary {
        let progress = Torrent.Progress(
            percentDone: percentDoneValue(in: dict) ?? 0,
            totalSize: intValue(for: "totalSize", in: dict) ?? 0,
            downloadedEver: intValue(for: "downloadedEver", in: dict) ?? 0,
            uploadedEver: intValue(for: "uploadedEver", in: dict) ?? 0,
            uploadRatio: doubleValue(for: "uploadRatio", in: dict) ?? 0,
            etaSeconds: intValue(for: "eta", in: dict) ?? 0
        )

        let transfer = Torrent.Transfer(
            downloadRate: intValue(for: "rateDownload", in: dict) ?? 0,
            uploadRate: intValue(for: "rateUpload", in: dict) ?? 0,
            downloadLimit: .init(
                isEnabled: boolValue(for: "downloadLimited", in: dict) ?? false,
                kilobytesPerSecond: intValue(for: "downloadLimit", in: dict) ?? 0
            ),
            uploadLimit: .init(
                isEnabled: boolValue(for: "uploadLimited", in: dict) ?? false,
                kilobytesPerSecond: intValue(for: "uploadLimit", in: dict) ?? 0
            )
        )

        let peers = Torrent.Peers(
            connected: intValue(for: "peersConnected", in: dict) ?? 0,
            sources: parsePeers(from: dict)
        )

        return Torrent.Summary(progress: progress, transfer: transfer, peers: peers)
    }

    private func makeDetails(from dict: [String: AnyCodable]) -> Torrent.Details {
        let downloadDir: String = stringValue(for: "downloadDir", in: dict) ?? ""
        let dateAddedSeconds: Int? = intValue(for: "dateAdded", in: dict)
        let addedDate: Date? = dateAddedSeconds.map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }

        return Torrent.Details(
            downloadDirectory: downloadDir,
            addedDate: addedDate,
            files: parseFiles(from: dict),
            trackers: parseTrackers(from: dict),
            trackerStats: parseTrackerStats(from: dict),
            speedSamples: []
        )
    }

    private func boolValue(for key: String, in dict: [String: AnyCodable]) -> Bool? {
        guard let value = dict[key] else { return nil }
        if case .bool(let boolValue) = value {
            return boolValue
        }
        return nil
    }

    private func stringValue(for key: String, in dict: [String: AnyCodable]) -> String? {
        guard let value = dict[key] else { return nil }
        if case .string(let stringValue) = value {
            return stringValue
        }
        return nil
    }
}
