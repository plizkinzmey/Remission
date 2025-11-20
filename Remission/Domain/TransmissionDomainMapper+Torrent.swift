import Foundation

extension TransmissionDomainMapper {
    func mapTorrentList(from response: TransmissionResponse) throws -> [Torrent] {
        let arguments: [String: AnyCodable] = try arguments(
            from: response,
            context: "torrent-get"
        )
        let torrentsValue: AnyCodable = try requireField(
            "torrents",
            in: arguments,
            context: "torrent-get"
        )

        guard case .array(let items) = torrentsValue else {
            throw DomainMappingError.invalidType(
                field: "torrents",
                expected: "array",
                context: "torrent-get"
            )
        }

        guard items.isEmpty == false else {
            return []
        }

        return try items.enumerated().map { index, item in
            guard case .object(let dict) = item else {
                throw DomainMappingError.invalidType(
                    field: "torrents[\(index)]",
                    expected: "object",
                    context: "torrent-get"
                )
            }
            return try mapTorrentObject(dict, includeDetails: false)
        }
    }

    func mapTorrentDetails(from response: TransmissionResponse) throws -> Torrent {
        let arguments: [String: AnyCodable] = try arguments(
            from: response,
            context: "torrent-get"
        )
        let torrentsValue: AnyCodable = try requireField(
            "torrents",
            in: arguments,
            context: "torrent-get"
        )

        guard case .array(let items) = torrentsValue else {
            throw DomainMappingError.invalidType(
                field: "torrents",
                expected: "array",
                context: "torrent-get"
            )
        }

        guard let first = items.first else {
            throw DomainMappingError.emptyCollection(context: "torrent-get")
        }

        guard case .object(let dict) = first else {
            throw DomainMappingError.invalidType(
                field: "torrents[0]",
                expected: "object",
                context: "torrent-get"
            )
        }

        return try mapTorrentObject(dict, includeDetails: true)
    }

    func mapTorrentAdd(from response: TransmissionResponse) throws -> TorrentRepository.AddResult {
        let arguments: [String: AnyCodable] = try arguments(
            from: response,
            context: "torrent-add"
        )

        if let addedValue = arguments["torrent-added"] {
            return try makeAddResult(
                from: addedValue,
                status: .added
            )
        }

        if let duplicateValue = arguments["torrent-duplicate"] {
            return try makeAddResult(
                from: duplicateValue,
                status: .duplicate
            )
        }

        throw DomainMappingError.missingField(
            field: "torrent-added|torrent-duplicate",
            context: "torrent-add"
        )
    }

    func mapTorrentObject(
        _ dict: [String: AnyCodable],
        includeDetails: Bool
    ) throws -> Torrent {
        let id: Int = try requireInt("id", in: dict, context: "torrent")
        let name: String = try requireString("name", in: dict, context: "torrent")
        let statusRaw: Int = try requireInt("status", in: dict, context: "torrent")

        guard let status: Torrent.Status = Torrent.Status(rawValue: statusRaw) else {
            throw DomainMappingError.unsupportedStatus(rawValue: statusRaw)
        }

        let summary: Torrent.Summary = makeSummary(from: dict)
        let details: Torrent.Details? = includeDetails ? makeDetails(from: dict) : nil

        return Torrent(
            id: Torrent.Identifier(rawValue: id),
            name: name,
            status: status,
            summary: summary,
            details: details
        )
    }

    func makeSummary(
        from dict: [String: AnyCodable]
    ) -> Torrent.Summary {
        Torrent.Summary(
            progress: .init(
                percentDone: percentDoneValue(in: dict),
                totalSize: intValue("totalSize", in: dict) ?? 0,
                downloadedEver: intValue("downloadedEver", in: dict) ?? 0,
                uploadedEver: intValue("uploadedEver", in: dict) ?? 0,
                uploadRatio: doubleValue("uploadRatio", in: dict) ?? 0.0,
                etaSeconds: intValue("eta", in: dict) ?? -1
            ),
            transfer: .init(
                downloadRate: intValue("rateDownload", in: dict) ?? 0,
                uploadRate: intValue("rateUpload", in: dict) ?? 0,
                downloadLimit: .init(
                    isEnabled: boolValue("downloadLimited", in: dict) ?? false,
                    kilobytesPerSecond: intValue("downloadLimit", in: dict) ?? 0
                ),
                uploadLimit: .init(
                    isEnabled: boolValue("uploadLimited", in: dict) ?? false,
                    kilobytesPerSecond: intValue("uploadLimit", in: dict) ?? 0
                )
            ),
            peers: .init(
                connected: intValue("peersConnected", in: dict) ?? 0,
                sources: peerSources(in: dict)
            )
        )
    }

    func makeDetails(
        from dict: [String: AnyCodable]
    ) -> Torrent.Details {
        Torrent.Details(
            downloadDirectory: stringValue("downloadDir", in: dict) ?? "",
            addedDate: dateValue("dateAdded", in: dict),
            files: torrentFiles(in: dict),
            trackers: torrentTrackers(in: dict),
            trackerStats: torrentTrackerStats(in: dict),
            speedSamples: []
        )
    }

    private func makeAddResult(
        from value: AnyCodable,
        status: TorrentRepository.AddStatus
    ) throws -> TorrentRepository.AddResult {
        guard case .object(let addObject) = value else {
            throw DomainMappingError.invalidType(
                field: status == .added ? "torrent-added" : "torrent-duplicate",
                expected: "object",
                context: "torrent-add"
            )
        }

        let id: Int = try requireInt("id", in: addObject, context: "torrent-add")
        let name: String = try requireString("name", in: addObject, context: "torrent-add")
        let hash: String = try requireString("hashString", in: addObject, context: "torrent-add")

        return TorrentRepository.AddResult(
            status: status,
            id: .init(rawValue: id),
            name: name,
            hashString: hash
        )
    }

    func percentDoneValue(
        in dict: [String: AnyCodable]
    ) -> Double {
        if let value = dict["percentDone"]?.doubleValue {
            return value
        }
        if let int = dict["percentDone"]?.intValue {
            if int > 1 {
                return Double(int) / 100.0
            } else {
                return Double(int)
            }
        }
        return 0.0
    }

    func peerSources(
        in dict: [String: AnyCodable]
    ) -> [Torrent.PeerSource] {
        guard let peersAny = dict["peersFrom"],
            case .object(let peersDict) = peersAny
        else {
            return []
        }

        return peersDict.compactMap { name, value in
            guard let count = value.intValue else { return nil }
            return Torrent.PeerSource(name: name, count: count)
        }
        .sorted(by: { $0.count > $1.count })
    }

    func torrentFiles(
        in dict: [String: AnyCodable]
    ) -> [Torrent.File] {
        guard let filesAny = dict["files"],
            case .array(let array) = filesAny
        else {
            return []
        }

        return array.enumerated().compactMap { index, value in
            guard case .object(let file) = value,
                let name = stringValue("name", in: file),
                let length = intValue("length", in: file),
                let bytesCompleted = intValue("bytesCompleted", in: file)
            else {
                return nil
            }

            let priority: Int = intValue("priority", in: file) ?? 1
            let wanted: Bool = boolValue("wanted", in: file) ?? true

            return Torrent.File(
                index: index,
                name: name,
                length: length,
                bytesCompleted: bytesCompleted,
                priority: priority,
                wanted: wanted
            )
        }
    }

    func torrentTrackers(
        in dict: [String: AnyCodable]
    ) -> [Torrent.Tracker] {
        guard let trackersAny = dict["trackers"],
            case .array(let array) = trackersAny
        else {
            return []
        }

        return array.compactMap { value in
            guard case .object(let tracker) = value,
                let announce = stringValue("announce", in: tracker)
            else {
                return nil
            }

            let tier: Int = intValue("tier", in: tracker) ?? 0
            let trackerId: Int =
                intValue("id", in: tracker)
                ?? intValue("trackerId", in: tracker)
                ?? tier

            return Torrent.Tracker(id: trackerId, announce: announce, tier: tier)
        }
    }

    func torrentTrackerStats(
        in dict: [String: AnyCodable]
    ) -> [Torrent.TrackerStat] {
        guard let statsAny = dict["trackerStats"],
            case .array(let array) = statsAny
        else {
            return []
        }

        return array.compactMap { value in
            guard case .object(let stat) = value else {
                return nil
            }

            let trackerId: Int =
                intValue("id", in: stat)
                ?? intValue("trackerId", in: stat)
                ?? 0

            let announceResult: String =
                stringValue(
                    "lastAnnounceResult",
                    in: stat
                ) ?? ""
            let downloadCount: Int = intValue("downloadCount", in: stat) ?? 0
            let leecherCount: Int = intValue("leecherCount", in: stat) ?? 0
            let seederCount: Int = intValue("seederCount", in: stat) ?? 0

            return Torrent.TrackerStat(
                trackerId: trackerId,
                lastAnnounceResult: announceResult,
                downloadCount: downloadCount,
                leecherCount: leecherCount,
                seederCount: seederCount
            )
        }
    }

    func dateValue(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Date? {
        guard let seconds = intValue(field, in: dict) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}
