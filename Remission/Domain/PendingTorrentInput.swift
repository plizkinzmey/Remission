import Foundation

/// Унифицированное представление входных данных для добавления торрента.
public struct PendingTorrentInput: Equatable, Sendable {
    public enum Payload: Equatable, Sendable {
        case torrentFile(data: Data, fileName: String?)
        case magnetLink(url: URL, rawValue: String)
    }

    public var payload: Payload
    public var sourceDescription: String

    public init(payload: Payload, sourceDescription: String) {
        self.payload = payload
        self.sourceDescription = sourceDescription
    }

    public var displayName: String {
        switch payload {
        case .torrentFile(_, let fileName):
            return fileName ?? "torrent"
        case .magnetLink(_, let rawValue):
            return rawValue
        }
    }

    public var isMagnetLink: Bool {
        if case .magnetLink = payload {
            return true
        }
        return false
    }
}
