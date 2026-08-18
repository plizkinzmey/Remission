import ComposableArchitecture
import Foundation

// MARK: - Error Types

extension ServerDetailReducer {
    enum FileImportResult: Equatable {
        case success(URL)
        case failure(String)
    }

    enum FileImportError: Equatable, Error {
        case failed(String)

        var message: String {
            switch self {
            case .failed(let message):
                return message
            }
        }
    }

    struct DeletionError: Equatable, Error {
        var message: String
    }

    enum DeletionResult: Equatable {
        case success
        case failure(DeletionError)
    }
}

extension ServerDetailReducer {
    struct ConnectionResponse: Equatable {
        var environment: ServerConnectionEnvironment
        var handshake: TransmissionHandshakeResult
    }
}
