import Foundation

typealias TorrentFile = Torrent.File
typealias TorrentTracker = Torrent.Tracker
typealias TrackerStat = Torrent.TrackerStat
typealias SpeedSample = Torrent.SpeedSample
typealias PeerSource = Torrent.PeerSource

extension Torrent.File {
    var progress: Double {
        guard length > 0 else { return 0.0 }
        return Double(bytesCompleted) / Double(length)
    }
}

extension Torrent.Tracker {
    var displayName: String {
        URL(string: announce)?.host ?? announce
    }
}
