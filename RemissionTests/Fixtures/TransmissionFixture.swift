import Foundation

@testable import Remission

/// Набор доступных Transmission фикстур.
enum TransmissionFixtureName: String, CaseIterable, Sendable {
    case sessionGetSuccessRPC17 = "Transmission/Session/session-get.success.rpc-17"
    case sessionGetIncompatibleRPC12 = "Transmission/Session/session-get.incompatible.rpc-12"
    case sessionGetInvalidArguments = "Transmission/Session/session-get.invalid.arguments"

    case torrentGetSingleActive = "Transmission/Torrents/torrent-get.success.single"
    case torrentAddSuccessMagnet = "Transmission/Torrents/torrent-add.success.magnet"
    case torrentStartSuccess = "Transmission/Torrents/torrent-start.success"
    case torrentStopSuccess = "Transmission/Torrents/torrent-stop.success"
    case torrentRemoveSuccessDeleteData =
        "Transmission/Torrents/torrent-remove.success.delete-data"

    case rpcErrorTooManyRequests = "Transmission/Errors/rpc-error.too-many-requests"
    case rpcErrorAuthFailed = "Transmission/Errors/rpc-error.auth-failed"
    case rpcErrorInvalidJSON = "Transmission/Errors/rpc-error.invalid-json"
}

enum TransmissionFixture {
    enum FixtureError: Error, CustomStringConvertible {
        case fileMissing(name: TransmissionFixtureName, url: URL)
        case decodingFailed(name: TransmissionFixtureName, underlying: Error)

        var description: String {
            switch self {
            case .fileMissing(let name, let url):
                return "Fixture \(name.rawValue) not found at \(url.path())"
            case .decodingFailed(let name, let underlying):
                return "Failed to decode fixture \(name.rawValue): \(underlying)"
            }
        }
    }

    private static let baseDirectory: URL = {
        let thisFileURL: URL = URL(fileURLWithPath: #filePath, isDirectory: false)
        return thisFileURL.deletingLastPathComponent()
    }()

    static func url(_ name: TransmissionFixtureName) throws -> URL {
        let fileURL: URL =
            baseDirectory
            .appendingPathComponent(name.rawValue)
            .appendingPathExtension("json")

        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw FixtureError.fileMissing(name: name, url: fileURL)
        }

        return fileURL
    }

    static func data(_ name: TransmissionFixtureName) throws -> Data {
        let fileURL: URL = try url(name)
        return try Data(contentsOf: fileURL)
    }

    static func response(_ name: TransmissionFixtureName) throws -> TransmissionResponse {
        do {
            let data: Data = try data(name)
            return try JSONDecoder().decode(TransmissionResponse.self, from: data)
        } catch {
            throw FixtureError.decodingFailed(name: name, underlying: error)
        }
    }
}

extension TransmissionMockResponsePlan {
    /// Создаёт план ответа на основе фикстуры Transmission.
    static func fixture(_ name: TransmissionFixtureName) throws -> TransmissionMockResponsePlan {
        let response: TransmissionResponse = try TransmissionFixture.response(name)

        if response.isSuccess {
            return .rpcSuccess(arguments: response.arguments, tag: response.tag)
        } else {
            return .rpcError(result: response.result)
        }
    }
}
