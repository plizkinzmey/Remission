import Foundation

extension TransmissionDomainMapper {
    func mapTorrentList(from response: TransmissionResponse) throws -> [Torrent] {
        let args = try decode(TorrentGetArguments.self, from: response.arguments)
        return try args.torrents.map { try map($0, includeDetails: false) }
    }

    func mapTorrentDetails(from response: TransmissionResponse) throws -> Torrent {
        let args = try decode(TorrentGetArguments.self, from: response.arguments)
        guard let first = args.torrents.first else {
            throw DomainMappingError.emptyCollection(context: "torrent-get")
        }
        return try map(first, includeDetails: true)
    }

    func mapTorrentAdd(from response: TransmissionResponse) throws -> TorrentRepository.AddResult {
        let args = try decode(TorrentAddArguments.self, from: response.arguments)

        if let added = args.torrentAdded {
            return TorrentRepository.AddResult(
                status: .added,
                id: .init(rawValue: added.id),
                name: added.name,
                hashString: added.hashString
            )
        }

        if let duplicate = args.torrentDuplicate {
            return TorrentRepository.AddResult(
                status: .duplicate,
                id: .init(rawValue: duplicate.id),
                name: duplicate.name,
                hashString: duplicate.hashString
            )
        }

        throw DomainMappingError.missingField(
            field: "torrent-added|torrent-duplicate",
            context: "torrent-add"
        )
    }

    // MARK: - Private Mapping Helpers

    private func map(_ dto: TorrentObject, includeDetails: Bool) throws -> Torrent {
        guard let status = Torrent.Status(rawValue: dto.status) else {
            throw DomainMappingError.unsupportedStatus(rawValue: dto.status)
        }

        let summary = Torrent.Summary(
            progress: mapProgress(dto),
            transfer: mapTransfer(dto),
            peers: mapPeers(dto)
        )

        let details: Torrent.Details? = includeDetails ? mapDetails(dto) : nil

        return Torrent(
            id: Torrent.Identifier(rawValue: dto.id),
            name: dto.name,
            status: status,
            error: dto.error ?? 0,
            errorString: dto.errorString ?? "",
            tags: dto.labels?.filter { !$0.isEmpty } ?? [],
            summary: summary,
            details: details
        )
    }

    private func mapProgress(_ dto: TorrentObject) -> Torrent.Progress {
        let rawPercent = dto.percentDone ?? 0.0
        let percentDone = rawPercent > 1.0 ? rawPercent / 100.0 : rawPercent

        let rawRecheck = dto.recheckProgress ?? 0.0
        let recheckProgress = rawRecheck > 1.0 ? rawRecheck / 100.0 : rawRecheck

        return Torrent.Progress(
            percentDone: percentDone,
            recheckProgress: recheckProgress,
            totalSize: dto.totalSize ?? 0,
            downloadedEver: dto.downloadedEver ?? 0,
            uploadedEver: dto.uploadedEver ?? 0,
            uploadRatio: dto.uploadRatio ?? 0.0,
            etaSeconds: dto.eta ?? -1
        )
    }

    private func mapTransfer(_ dto: TorrentObject) -> Torrent.Transfer {
        Torrent.Transfer(
            downloadRate: dto.rateDownload ?? 0,
            uploadRate: dto.rateUpload ?? 0,
            downloadLimit: .init(
                isEnabled: dto.downloadLimited ?? false,
                kilobytesPerSecond: dto.downloadLimit ?? 0
            ),
            uploadLimit: .init(
                isEnabled: dto.uploadLimited ?? false,
                kilobytesPerSecond: dto.uploadLimit ?? 0
            )
        )
    }

    private func mapPeers(_ dto: TorrentObject) -> Torrent.Peers {
        let sources =
            dto.peersFrom?.compactMap { name, count -> Torrent.PeerSource? in
                guard count > 0 else { return nil }
                return Torrent.PeerSource(name: name, count: count)
            }
            .sorted(by: { $0.count > $1.count }) ?? []

        return Torrent.Peers(
            connected: dto.peersConnected ?? 0,
            sources: sources
        )
    }

    private func mapDetails(_ dto: TorrentObject) -> Torrent.Details {
        let addedTimestamp = dto.addedDate ?? dto.dateAdded
        let addedDate = addedTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) }

        return Torrent.Details(
            downloadDirectory: dto.downloadDir ?? "",
            addedDate: addedDate,
            files: mapFiles(dto),
            trackers: mapTrackers(dto),
            trackerStats: mapTrackerStats(dto),
            speedSamples: []
        )
    }

    private func mapFiles(_ dto: TorrentObject) -> [Torrent.File] {
        guard let files = dto.files else { return [] }
        let stats = dto.fileStats ?? []

        return files.enumerated().map { index, file in
            let stat = stats.indices.contains(index) ? stats[index] : nil
            return Torrent.File(
                index: index,
                name: file.name,
                length: file.length,
                bytesCompleted: file.bytesCompleted,
                priority: stat?.priority ?? 0,
                wanted: stat?.wanted ?? true
            )
        }
    }

    private func mapTrackers(_ dto: TorrentObject) -> [Torrent.Tracker] {
        dto.trackers?.map { tracker in
            Torrent.Tracker(
                id: tracker.id ?? tracker.trackerId ?? tracker.tier,
                announce: tracker.announce,
                tier: tracker.tier
            )
        } ?? []
    }

    private func mapTrackerStats(_ dto: TorrentObject) -> [Torrent.TrackerStat] {
        dto.trackerStats?.map { stat in
            Torrent.TrackerStat(
                trackerId: stat.id ?? stat.trackerId ?? 0,
                lastAnnounceResult: stat.lastAnnounceResult,
                downloadCount: stat.downloadCount,
                leecherCount: stat.leecherCount,
                seederCount: stat.seederCount
            )
        } ?? []
    }
}

// MARK: - RPC DTO Models

struct TorrentGetArguments: Decodable {
    let torrents: [TorrentObject]
}

struct TorrentAddArguments: Decodable {
    let torrentAdded: TorrentAddObject?
    let torrentDuplicate: TorrentAddObject?

    enum CodingKeys: String, CodingKey {
        case torrentAdded = "torrent-added"
        case torrentDuplicate = "torrent-duplicate"
    }
}

struct TorrentAddObject: Decodable {
    let id: Int
    let name: String
    let hashString: String
}

struct TorrentObject: Decodable {
    let id: Int
    let name: String
    let status: Int
    let error: Int?
    let errorString: String?
    let labels: [String]?

    // Progress
    let percentDone: Double?
    let recheckProgress: Double?
    let totalSize: Int?
    let downloadedEver: Int?
    let uploadedEver: Int?
    let uploadRatio: Double?
    let eta: Int?

    // Transfer
    let rateDownload: Int?
    let rateUpload: Int?
    let downloadLimited: Bool?
    let downloadLimit: Int?
    let uploadLimited: Bool?
    let uploadLimit: Int?

    // Peers
    let peersConnected: Int?
    let peersFrom: [String: Int]?

    // Details
    let downloadDir: String?
    let addedDate: Int?
    let dateAdded: Int?

    let files: [FileObject]?
    let fileStats: [FileStatObject]?
    let trackers: [TrackerObject]?
    let trackerStats: [TrackerStatObject]?
}

struct FileObject: Decodable {
    let name: String
    let length: Int
    let bytesCompleted: Int
}

struct FileStatObject: Decodable {
    let priority: Int
    let wanted: Bool
}

struct TrackerObject: Decodable {
    let id: Int?
    let trackerId: Int?
    let announce: String
    let tier: Int
}

struct TrackerStatObject: Decodable {
    let id: Int?
    let trackerId: Int?
    let lastAnnounceResult: String
    let downloadCount: Int
    let leecherCount: Int
    let seederCount: Int
}
