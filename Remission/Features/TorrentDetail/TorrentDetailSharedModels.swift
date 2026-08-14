import ComposableArchitecture
import Foundation

struct TorrentDetailSpeedHistory: Equatable {
    var samples: [Torrent.SpeedSample] = []
    var capacity: Int = 20

    mutating func append(timestamp: Date, downloadRate: Int, uploadRate: Int) {
        samples.append(
            Torrent.SpeedSample(
                timestamp: timestamp,
                downloadRate: downloadRate,
                uploadRate: uploadRate
            )
        )
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    mutating func reset() { samples.removeAll() }
}

struct TorrentDetailPendingStatusChange: Equatable {
    var command: TorrentDetailReducer.CommandKind
    var initialStatus: Int
}

enum CategoryUpdateResult: Equatable {
    case success
    case failure(String)
}
