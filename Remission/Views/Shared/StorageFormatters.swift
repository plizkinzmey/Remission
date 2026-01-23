import Foundation

enum StorageFormatters {
    static func bytes(_ bytes: Int64) -> String {
        TorrentDataFormatter.bytes(bytes)
    }
}
