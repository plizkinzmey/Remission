/// Список полей `torrent-get`, необходимых для отображения сводного списка.
enum TorrentListFields {
    /// Поля, достаточные для `Torrent.Summary`.
    static let summary: [String] = [
        "id",
        "name",
        "status",
        "percentDone",
        "totalSize",
        "downloadedEver",
        "uploadedEver",
        "uploadRatio",
        "eta",
        "rateDownload",
        "rateUpload",
        "downloadLimit",
        "downloadLimited",
        "uploadLimit",
        "uploadLimited",
        "peersConnected",
        "peersFrom"
    ]
}
