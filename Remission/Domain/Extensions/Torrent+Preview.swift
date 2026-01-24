import Foundation

extension Torrent {
    /// Пример торрента, который сейчас скачивается.
    static let previewDownloading: Torrent = {
        let zeroLimits = Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0)
        let summary = Summary(
            progress: .init(
                percentDone: 0.42,
                recheckProgress: 0.0,
                totalSize: 4_200_000_000,
                downloadedEver: 1_800_000_000,
                uploadedEver: 120_000_000,
                uploadRatio: 0.06,
                etaSeconds: 3600
            ),
            transfer: .init(
                downloadRate: 1_250_000,
                uploadRate: 45_000,
                downloadLimit: zeroLimits,
                uploadLimit: zeroLimits
            ),
            peers: .init(connected: 12, sources: [])
        )
        return Torrent(
            id: .init(rawValue: 1),
            name: "ubuntu-24.04-desktop-amd64.iso",
            status: .downloading,
            tags: ["iso", "linux"],
            summary: summary
        )
    }()

    /// Пример торрента, который полностью скачан и раздаётся.
    static let previewCompleted: Torrent = {
        let zeroLimits = Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0)
        let summary = Summary(
            progress: .init(
                percentDone: 1.0,
                recheckProgress: 0.0,
                totalSize: 1_200_000_000,
                downloadedEver: 1_200_000_000,
                uploadedEver: 2_400_000_000,
                uploadRatio: 2.0,
                etaSeconds: -1
            ),
            transfer: .init(
                downloadRate: 0,
                uploadRate: 850_000,
                downloadLimit: zeroLimits,
                uploadLimit: zeroLimits
            ),
            peers: .init(connected: 42, sources: [])
        )
        return Torrent(
            id: .init(rawValue: 2),
            name: "The.Grand.Tour.S05E03.1080p.mkv",
            status: .seeding,
            tags: ["series", "video"],
            summary: summary
        )
    }()
}

// MARK: - AppBootstrap Samples

extension Torrent {
    static func sampleDownloading() -> Torrent {
        var torrent = previewDownloading
        torrent.id = .init(rawValue: 1_001)
        torrent.name = "Ubuntu 25.04 Desktop"
        torrent.status = .downloading
        torrent.summary.progress.percentDone = 0.58
        torrent.summary.progress.downloadedEver = 9_100_000_000
        torrent.summary.progress.etaSeconds = 2_400
        torrent.summary.transfer.downloadRate = 3_500_000
        torrent.summary.transfer.uploadRate = 420_000
        return torrent
    }

    static func sampleSeeding() -> Torrent {
        var torrent = previewCompleted
        torrent.id = .init(rawValue: 1_002)
        torrent.name = "Fedora 41 Workstation"
        torrent.status = .seeding
        torrent.summary.transfer.uploadRate = 620_000
        return torrent
    }

    static func samplePaused() -> Torrent {
        var torrent = previewDownloading
        torrent.id = .init(rawValue: 1_003)
        torrent.name = "Arch Linux Snapshot"
        torrent.status = .stopped
        torrent.summary.progress.percentDone = 0.12
        torrent.summary.transfer.downloadRate = 0
        torrent.summary.transfer.uploadRate = 0
        torrent.summary.progress.etaSeconds = -1
        return torrent
    }
}
