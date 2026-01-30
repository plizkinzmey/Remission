import Foundation

@testable import Remission

enum TransmissionFixture {
    enum ResponseType {
        case torrentGetSingleActive
        case rpcErrorAuthFailed
        case sessionGetSuccessRpc17

        var path: String {
            switch self {
            case .torrentGetSingleActive:
                return "Torrents/torrent-get.success.single.json"
            case .rpcErrorAuthFailed:
                return "Errors/rpc-error.auth-failed.json"
            case .sessionGetSuccessRpc17:
                return "Session/session-get.success.rpc-17.json"
            }
        }
    }

    static func response(_ type: ResponseType) throws -> TransmissionResponse {
        try TransmissionFixtureLoader.loadResponse(type.path)
    }
}
