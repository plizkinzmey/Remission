import Foundation

// MARK: - RPC Arguments Wrapper

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

// MARK: - Torrent Object

struct TorrentObject: Decodable {
    let id: Int
    let name: String
    let status: Int
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

// MARK: - Nested Objects

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
    let trackerId: Int?  // fallback for id
    let announce: String
    let tier: Int
}

struct TrackerStatObject: Decodable {
    let id: Int?
    let trackerId: Int?  // fallback
    let lastAnnounceResult: String
    let downloadCount: Int
    let leecherCount: Int
    let seederCount: Int
}
